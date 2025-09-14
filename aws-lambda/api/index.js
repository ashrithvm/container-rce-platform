const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { createClient } = require('redis');
const { v4: uuidv4 } = require('uuid');

// Initialize AWS clients
const sqsClient = new SQSClient({ region: process.env.AWS_REGION || 'us-east-1' });
const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

// Redis client (will be initialized in handler)
let redisClient = null;

// Language configurations
const LANGUAGE_CONFIGS = {
  cpp: {
    extension: 'cpp',
    timeout: 30000,
    memoryLimit: '512m'
  },
  java: {
    extension: 'java',
    timeout: 60000,
    memoryLimit: '1g'
  },
  python: {
    extension: 'py',
    timeout: 30000,
    memoryLimit: '512m'
  },
  javascript: {
    extension: 'js',
    timeout: 30000,
    memoryLimit: '512m'
  }
};

// Validation functions
const validateCode = (code, language) => {
  if (!code || code.trim() === '') {
    return { isValid: false, message: 'Code is required. Please provide code to execute.' };
  }

  if (code.length > 10000) {
    return { isValid: false, message: 'Code exceeds the maximum size of 10,000 characters.' };
  }

  if (!LANGUAGE_CONFIGS[language]) {
    return { isValid: false, message: `Language ${language} is not supported.` };
  }

  // Basic syntax validation patterns
  const syntaxChecks = {
    cpp: /^#include\s+<[^>]+>|^using\s+namespace\s+std;|int\s+main\s*\(/m,
    java: /class\s+\w+|public\s+static\s+void\s+main/m,
    python: /^(def|import|from|print|if|for|while)/m,
    javascript: /^(function|const|let|var|console\.log)/m
  };

  // Simple syntax check (optional - can be enhanced)
  const pattern = syntaxChecks[language];
  if (pattern && !pattern.test(code)) {
    return { 
      isValid: false, 
      message: `Code appears to have syntax issues. Please check your ${language} syntax.` 
    };
  }

  return { isValid: true };
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

// Store job status in Redis
const setJobStatus = async (jobId, status, data = null) => {
  try {
    const redis = await initializeRedis();
    const jobData = {
      status,
      timestamp: Date.now(),
      ...(data && { data })
    };
    
    await redis.setEx(`job:${jobId}`, 3600, JSON.stringify(jobData)); // Expire after 1 hour
  } catch (error) {
    console.error('Error setting job status in Redis:', error);
  }
};

// Get job status from Redis
const getJobStatus = async (jobId) => {
  try {
    const redis = await initializeRedis();
    const jobData = await redis.get(`job:${jobId}`);
    
    if (!jobData) {
      return null;
    }
    
    return JSON.parse(jobData);
  } catch (error) {
    console.error('Error getting job status from Redis:', error);
    return null;
  }
};

// Store code in S3
const storeCodeInS3 = async (jobId, code, language) => {
  const key = `jobs/${jobId}/code.${LANGUAGE_CONFIGS[language].extension}`;
  
  const params = {
    Bucket: process.env.S3_CODE_BUCKET,
    Key: key,
    Body: code,
    ContentType: 'text/plain',
    ServerSideEncryption: 'AES256',
    Metadata: {
      language,
      jobId,
      timestamp: Date.now().toString()
    }
  };

  try {
    await s3Client.send(new PutObjectCommand(params));
    return key;
  } catch (error) {
    console.error('Error storing code in S3:', error);
    throw error;
  }
};

// Send message to SQS
const sendToExecutionQueue = async (jobData) => {
  const params = {
    QueueUrl: process.env.SQS_QUEUE_URL,
    MessageBody: JSON.stringify(jobData),
    MessageAttributes: {
      language: {
        DataType: 'String',
        StringValue: jobData.language
      },
      jobId: {
        DataType: 'String',
        StringValue: jobData.jobId
      }
    }
  };

  try {
    const result = await sqsClient.send(new SendMessageCommand(params));
    return result.MessageId;
  } catch (error) {
    console.error('Error sending message to SQS:', error);
    throw error;
  }
};

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
};

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));
  
  try {
    const { httpMethod, path, pathParameters, body } = event;

    // Handle preflight CORS requests
    if (httpMethod === 'OPTIONS') {
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'CORS preflight successful' })
      };
    }

    // Route requests
    if (httpMethod === 'POST' && path === '/execute') {
      return await handleExecute(body);
    }
    
    if (httpMethod === 'GET' && path.startsWith('/job-status/')) {
      const jobId = pathParameters?.jobId;
      if (!jobId) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Job ID is required' })
        };
      }
      return await handleJobStatus(jobId);
    }

    // Route not found
    return {
      statusCode: 404,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Route not found' })
    };

  } catch (error) {
    console.error('Handler error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      })
    };
  }
};

// Handle code execution request
const handleExecute = async (body) => {
  try {
    if (!body) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Request body is required' })
      };
    }

    const { code, language } = JSON.parse(body);

    // Validate input
    const validation = validateCode(code, language);
    if (!validation.isValid) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: validation.message })
      };
    }

    // Generate job ID
    const jobId = uuidv4();

    // Store code in S3
    const codeKey = await storeCodeInS3(jobId, code, language);

    // Set initial job status
    await setJobStatus(jobId, 'queued', { language, codeKey });

    // Send job to execution queue
    const messageId = await sendToExecutionQueue({
      jobId,
      language,
      codeKey,
      timestamp: Date.now(),
      timeout: LANGUAGE_CONFIGS[language].timeout,
      memoryLimit: LANGUAGE_CONFIGS[language].memoryLimit
    });

    console.log(`Job ${jobId} queued with SQS message ID: ${messageId}`);

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ 
        jobId, 
        status: 'queued',
        message: 'Code execution job has been queued successfully' 
      })
    };

  } catch (error) {
    console.error('Execute handler error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        error: 'Failed to queue code execution',
        message: error.message 
      })
    };
  }
};

// Handle job status request
const handleJobStatus = async (jobId) => {
  try {
    const jobStatus = await getJobStatus(jobId);
    
    if (!jobStatus) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Job not found' })
      };
    }

    // Structure response based on status
    const response = {
      status: jobStatus.status,
      timestamp: jobStatus.timestamp
    };

    if (jobStatus.status === 'completed' && jobStatus.data?.result) {
      response.result = jobStatus.data.result;
    }

    if (jobStatus.status === 'failed' && jobStatus.data?.error) {
      response.error = jobStatus.data.error;
    }

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify(response)
    };

  } catch (error) {
    console.error('Job status handler error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        error: 'Failed to get job status',
        message: error.message 
      })
    };
  }
};
