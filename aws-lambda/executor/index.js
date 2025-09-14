const { S3Client, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { createClient } = require('redis');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

// Initialize AWS clients
const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

// Redis client (will be initialized in handler)
let redisClient = null;

// Language execution configurations
const LANGUAGE_CONFIGS = {
  cpp: {
    extension: 'cpp',
    compile: (filepath) => ({
      command: 'g++',
      args: ['-std=c++17', '-O2', '-o', filepath.replace('.cpp', ''), filepath],
      timeout: 30000
    }),
    execute: (filepath) => ({
      command: filepath.replace('.cpp', ''),
      args: [],
      timeout: 15000
    })
  },
  java: {
    extension: 'java',
    compile: (filepath) => ({
      command: 'javac',
      args: [filepath],
      timeout: 30000
    }),
    execute: (filepath) => {
      const className = path.basename(filepath, '.java');
      const dir = path.dirname(filepath);
      return {
        command: 'java',
        args: ['-cp', dir, className],
        timeout: 15000
      };
    }
  },
  python: {
    extension: 'py',
    compile: null, // Python doesn't need compilation
    execute: (filepath) => ({
      command: 'python3',
      args: [filepath],
      timeout: 15000
    })
  },
  javascript: {
    extension: 'js',
    compile: null, // JavaScript doesn't need compilation
    execute: (filepath) => ({
      command: 'node',
      args: [filepath],
      timeout: 15000
    })
  }
};

// Initialize Redis connection
const initializeRedis = async () => {
  if (!redisClient) {
    redisClient = createClient({
      socket: {
        host: process.env.REDIS_ENDPOINT,
        port: process.env.REDIS_PORT || 6379,
        tls: true // ElastiCache with encryption in transit
      }
    });

    redisClient.on('error', (err) => {
      console.error('Redis Client Error:', err);
    });

    await redisClient.connect();
  }
  return redisClient;
};

// Update job status in Redis
const updateJobStatus = async (jobId, status, data = null) => {
  try {
    const redis = await initializeRedis();
    const jobData = {
      status,
      timestamp: Date.now(),
      ...(data && { data })
    };
    
    await redis.setEx(`job:${jobId}`, 3600, JSON.stringify(jobData)); // Expire after 1 hour
    console.log(`Job ${jobId} status updated to: ${status}`);
  } catch (error) {
    console.error(`Error updating job ${jobId} status in Redis:`, error);
  }
};

// Download code from S3
const downloadCodeFromS3 = async (codeKey) => {
  const params = {
    Bucket: process.env.S3_CODE_BUCKET,
    Key: codeKey
  };

  try {
    const result = await s3Client.send(new GetObjectCommand(params));
    const chunks = [];
    
    for await (const chunk of result.Body) {
      chunks.push(chunk);
    }
    
    return Buffer.concat(chunks).toString('utf-8');
  } catch (error) {
    console.error('Error downloading code from S3:', error);
    throw error;
  }
};

// Clean up S3 object
const cleanupS3Object = async (codeKey) => {
  try {
    const params = {
      Bucket: process.env.S3_CODE_BUCKET,
      Key: codeKey
    };
    
    await s3Client.send(new DeleteObjectCommand(params));
    console.log(`Cleaned up S3 object: ${codeKey}`);
  } catch (error) {
    console.error(`Error cleaning up S3 object ${codeKey}:`, error);
  }
};

// Execute command with timeout
const executeCommand = (command, args, options = {}) => {
  return new Promise((resolve, reject) => {
    const timeout = options.timeout || 15000;
    const cwd = options.cwd || process.cwd();
    
    console.log(`Executing: ${command} ${args.join(' ')}`);
    
    const child = spawn(command, args, {
      cwd,
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: timeout,
      killSignal: 'SIGKILL'
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    const timeoutId = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error(`Command timed out after ${timeout}ms`));
    }, timeout);

    child.on('close', (code) => {
      clearTimeout(timeoutId);
      
      const result = {
        code,
        stdout: stdout.trim(),
        stderr: stderr.trim()
      };
      
      if (code === 0) {
        resolve(result);
      } else {
        reject(new Error(stderr || `Command failed with exit code ${code}`));
      }
    });

    child.on('error', (error) => {
      clearTimeout(timeoutId);
      reject(error);
    });
  });
};

// Create temporary file
const createTempFile = async (code, language, jobId) => {
  const config = LANGUAGE_CONFIGS[language];
  const tempDir = os.tmpdir();
  
  let filename;
  if (language === 'java') {
    // Extract class name for Java
    const classMatch = code.match(/class\s+(\w+)/);
    const className = classMatch ? classMatch[1] : 'Main';
    filename = `${className}.${config.extension}`;
  } else {
    filename = `code_${jobId}.${config.extension}`;
  }
  
  const filepath = path.join(tempDir, filename);
  
  try {
    await fs.promises.writeFile(filepath, code, 'utf8');
    console.log(`Created temp file: ${filepath}`);
    return filepath;
  } catch (error) {
    console.error('Error creating temp file:', error);
    throw error;
  }
};

// Clean up temporary files
const cleanupTempFiles = async (filepath) => {
  try {
    const dir = path.dirname(filepath);
    const basename = path.basename(filepath, path.extname(filepath));
    
    // Remove source file
    if (fs.existsSync(filepath)) {
      await fs.promises.unlink(filepath);
      console.log(`Cleaned up temp file: ${filepath}`);
    }
    
    // Remove compiled executable (C++, Java class files)
    const executablePath = path.join(dir, basename);
    if (fs.existsSync(executablePath)) {
      await fs.promises.unlink(executablePath);
      console.log(`Cleaned up executable: ${executablePath}`);
    }
    
    // Clean up Java class files
    const classFilePath = filepath.replace('.java', '.class');
    if (fs.existsSync(classFilePath)) {
      await fs.promises.unlink(classFilePath);
      console.log(`Cleaned up class file: ${classFilePath}`);
    }
    
  } catch (error) {
    console.error('Error during cleanup:', error);
  }
};

// Execute code
const executeCode = async (code, language, jobId, options = {}) => {
  let filepath = null;
  
  try {
    const config = LANGUAGE_CONFIGS[language];
    if (!config) {
      throw new Error(`Unsupported language: ${language}`);
    }

    // Create temporary file
    filepath = await createTempFile(code, language, jobId);

    // Compile if necessary
    if (config.compile) {
      console.log(`Compiling ${language} code...`);
      const compileConfig = config.compile(filepath);
      await executeCommand(compileConfig.command, compileConfig.args, {
        timeout: compileConfig.timeout
      });
      console.log(`Compilation successful for ${language}`);
    }

    // Execute
    console.log(`Executing ${language} code...`);
    const executeConfig = config.execute(filepath);
    const result = await executeCommand(executeConfig.command, executeConfig.args, {
      timeout: executeConfig.timeout
    });

    const output = result.stdout || 'Program executed successfully (no output)';
    
    return {
      success: true,
      output: output,
      executionTime: Date.now() // This would be more accurate with actual timing
    };

  } catch (error) {
    console.error(`Execution error for ${language}:`, error);
    
    return {
      success: false,
      error: error.message,
      output: null
    };
  } finally {
    // Always cleanup temp files
    if (filepath) {
      await cleanupTempFiles(filepath);
    }
  }
};

exports.handler = async (event) => {
  console.log('Executor Lambda triggered with event:', JSON.stringify(event, null, 2));

  // Process SQS records
  for (const record of event.Records) {
    let jobData = null;
    
    try {
      jobData = JSON.parse(record.body);
      const { jobId, language, codeKey, timeout, memoryLimit } = jobData;
      
      console.log(`Processing job ${jobId} for language ${language}`);
      
      // Update job status to active
      await updateJobStatus(jobId, 'active');
      
      // Download code from S3
      console.log(`Downloading code from S3: ${codeKey}`);
      const code = await downloadCodeFromS3(codeKey);
      
      // Execute the code
      const startTime = Date.now();
      const result = await executeCode(code, language, jobId, {
        timeout: timeout || 15000,
        memoryLimit: memoryLimit || '512m'
      });
      const endTime = Date.now();
      const executionTime = endTime - startTime;
      
      // Update job status based on result
      if (result.success) {
        await updateJobStatus(jobId, 'completed', {
          result: result.output,
          executionTime: executionTime,
          language: language
        });
        console.log(`Job ${jobId} completed successfully in ${executionTime}ms`);
      } else {
        await updateJobStatus(jobId, 'failed', {
          error: result.error,
          executionTime: executionTime,
          language: language
        });
        console.log(`Job ${jobId} failed: ${result.error}`);
      }
      
      // Clean up S3 object
      await cleanupS3Object(codeKey);
      
    } catch (error) {
      console.error('Error processing SQS record:', error);
      
      // Update job status to failed if we have job data
      if (jobData && jobData.jobId) {
        await updateJobStatus(jobData.jobId, 'failed', {
          error: error.message || 'Unknown error during code execution',
          language: jobData.language || 'unknown'
        });
        
        // Attempt cleanup even on error
        if (jobData.codeKey) {
          await cleanupS3Object(jobData.codeKey);
        }
      }
    }
  }
  
  return {
    statusCode: 200,
    body: JSON.stringify({
      message: `Processed ${event.Records.length} job(s)`
    })
  };
};
