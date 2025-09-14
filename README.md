# AWS Cloud-Native Remote Code Execution (RCE) Platform

A fully serverless, cloud-native web application built on AWS that allows users to write, submit, and execute code in multiple languages (C++, Java, Python, JavaScript) with enterprise-grade security, scalability, and cost efficiency.

## 🏗️ Architecture

### Cloud-Native AWS Architecture

This platform leverages AWS services for maximum efficiency, scalability, and cost optimization:

```
┌─────────────────────────────────────────────────────────────────┐
│                     User's Browser                             │
│  ┌─────────────────┐                                            │
│  │  React SPA      │                                            │
│  │  (CloudFront)   │                                            │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API Gateway (REST)                        │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │ POST /execute   │  │ GET /job-status │                      │
│  └─────────────────┘  └─────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Lambda Functions                           │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   API Lambda    │  │ Executor Lambda │                      │
│  │ (Job Creation)  │  │ (Code Execution)│                      │
│  └─────────────────┘  └─────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
                │                          │
                ▼                          ▼
┌─────────────────┐              ┌─────────────────┐
│  SQS Queue      │              │ ElastiCache     │
│  (Job Queue)    │              │ (Job Status)    │
└─────────────────┘              └─────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        S3 Storage                              │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │ Code Storage    │  │ Frontend Assets │                      │
│  │  (Temporary)    │  │   (Static Web)  │                      │
│  └─────────────────┘  └─────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

### 🚀 Key Architectural Benefits

1. **Maximum Efficiency (Priority 1)**:
   - **Pay-per-execution model**: Lambda functions only charge when code is executed
   - **Auto-scaling**: No idle resources, scales from 0 to thousands of executions
   - **Cold start optimization**: Efficient code execution with minimal latency
   - **Resource limits**: Memory and CPU constraints prevent runaway processes

2. **Scalability (Priority 2)**:
   - **Horizontal scaling**: SQS queue handles millions of messages
   - **Concurrent execution**: Multiple Lambda instances process jobs in parallel
   - **Global distribution**: CloudFront serves frontend globally
   - **Elastic caching**: Redis scales based on demand

3. **Security**:
   - **Isolated execution**: Each code execution runs in a separate Lambda environment
   - **VPC isolation**: Lambda functions run in private subnets
   - **Encryption**: All data encrypted at rest and in transit
   - **IAM permissions**: Least privilege access controls

4. **Cost Optimization**:
   - **No idle infrastructure**: Pay only for actual usage
   - **Efficient resource allocation**: Right-sized Lambda functions
   - **Content delivery**: CloudFront reduces bandwidth costs
   - **Auto-expiring storage**: Temporary code files auto-delete

## 🛠️ Technology Stack

### Frontend
- **React 18** - Modern UI library
- **Tailwind CSS** - Utility-first CSS framework
- **Monaco Editor** - VS Code editor engine
- **Axios** - HTTP client for API calls

### Backend (AWS Services)
- **AWS Lambda** - Serverless compute for API and execution
- **Amazon API Gateway** - RESTful API management
- **Amazon SQS** - Message queue for job management
- **Amazon ElastiCache (Redis)** - In-memory data store for job status
- **Amazon S3** - Object storage for code and static assets
- **Amazon CloudFront** - Global content delivery network

### Infrastructure
- **Terraform** - Infrastructure as Code
- **AWS VPC** - Network isolation and security
- **AWS IAM** - Identity and access management
- **Amazon CloudWatch** - Monitoring and logging

## 📋 Prerequisites

- **AWS CLI** (v2.0+) - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- **Terraform** (v1.0+) - [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Node.js** (v18+) - [Download](https://nodejs.org/)
- **AWS Account** with appropriate permissions

## ⚡ Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/your-username/container-rce-platform.git
cd container-rce-platform

# Install frontend dependencies
npm install

# Install Lambda function dependencies
cd aws-lambda/api && npm install && cd ../..
cd aws-lambda/executor && npm install && cd ../..
```

### 2. Configure AWS Credentials

```bash
aws configure
# Provide your AWS Access Key ID, Secret Access Key, and preferred region
```

### 3. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferred settings
```

### 4. Deploy to AWS

```bash
# Deploy everything with one command
npm run deploy

# Or deploy step by step:
npm run tf:init    # Initialize Terraform
npm run tf:plan    # Review deployment plan
npm run tf:apply   # Deploy infrastructure
```

### 5. Access Your Application

After deployment completes, you'll receive:
- **CloudFront URL**: Your global application URL
- **API Gateway URL**: Direct API endpoint

## 🔧 Deployment Options

### Automated Deployment
```bash
# Full deployment (recommended)
./scripts/deploy.sh

# Plan only (dry run)
./scripts/deploy.sh plan

# Destroy all resources
./scripts/deploy.sh destroy
```

### Manual Deployment
```bash
# Initialize Terraform
npm run tf:init

# Plan deployment
npm run tf:plan

# Apply infrastructure
npm run tf:apply

# Update Lambda functions only
npm run update:lambda:api
npm run update:lambda:executor
```

## 📊 Cost Optimization

### Estimated Monthly Costs (US East - Light Usage)

| Service | Usage | Cost |
|---------|--------|------|
| Lambda | 10,000 executions/month | ~$0.20 |
| API Gateway | 10,000 requests/month | ~$0.04 |
| ElastiCache | t3.micro, single node | ~$15.00 |
| S3 | 1GB storage, 1GB transfer | ~$0.05 |
| CloudFront | 1GB transfer | ~$0.09 |
| SQS | 10,000 messages | ~$0.004 |
| **Total** | | **~$15.38/month** |

### Cost Optimization Features
- **Auto-scaling**: Resources scale to zero when not in use
- **S3 Lifecycle**: Temporary files auto-delete after 1 day
- **Lambda right-sizing**: Memory allocation optimized per language
- **CloudFront caching**: Reduces origin requests

## 🔐 Security Features

### Network Security
- **VPC Isolation**: Lambda functions run in private subnets
- **Security Groups**: Restrictive firewall rules
- **NAT Gateways**: Secure internet access for Lambda functions

### Data Security
- **Encryption at Rest**: S3 and ElastiCache use AES-256
- **Encryption in Transit**: TLS 1.2+ for all communications
- **IAM Policies**: Least privilege access controls
- **Temporary Storage**: Code files auto-expire

### Code Execution Security
- **Isolated Environments**: Each execution in separate Lambda container
- **Resource Limits**: Memory and CPU constraints
- **Timeout Protection**: Execution time limits prevent infinite loops
- **Syntax Validation**: Pre-execution code validation

## 📈 Monitoring and Observability

### CloudWatch Integration
- **Lambda Metrics**: Duration, errors, invocations
- **API Gateway**: Request count, latency, errors
- **SQS Metrics**: Queue depth, message processing
- **Custom Alarms**: Automated alerting for failures

### Monitoring Dashboard
Access the CloudWatch dashboard for real-time metrics:
- Lambda execution statistics
- API performance metrics
- Queue processing rates
- Error rates and patterns

## 🎯 Supported Languages

| Language | Runtime | Compile Time | Execute Time |
|----------|---------|--------------|--------------|
| **C++** | GCC 11+ | ~5 seconds | ~2 seconds |
| **Java** | OpenJDK 17 | ~10 seconds | ~3 seconds |
| **Python** | Python 3.9 | N/A | ~1 second |
| **JavaScript** | Node.js 20 | N/A | ~1 second |

## 🚨 API Reference

### Execute Code
```http
POST /execute
Content-Type: application/json

{
  "code": "print('Hello, World!')",
  "language": "python"
}
```

**Response:**
```json
{
  "jobId": "uuid-v4",
  "status": "queued",
  "message": "Code execution job has been queued successfully"
}
```

### Get Job Status
```http
GET /job-status/{jobId}
```

**Response (Completed):**
```json
{
  "status": "completed",
  "result": "Hello, World!",
  "timestamp": 1640995200000
}
```

**Response (Failed):**
```json
{
  "status": "failed",
  "error": "Syntax error: invalid syntax",
  "timestamp": 1640995200000
}
```

## 🔄 CI/CD Integration

### GitHub Actions Example
```yaml
name: Deploy RCE Platform
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - name: Deploy
        run: ./scripts/deploy.sh
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## 🛠️ Development

### Local Development
```bash
# Start local development (uses original architecture)
npm run dev

# Build for production
npm run build

# Test Lambda functions locally (with SAM CLI)
sam local start-api
```

### Environment Variables
- `REACT_APP_API_BASE_URL`: API Gateway endpoint
- `AWS_REGION`: AWS region for deployment
- `ENVIRONMENT`: Deployment environment (dev/staging/prod)

## 🔧 Troubleshooting

### Common Issues

1. **Lambda Cold Starts**
   - Implement connection pooling for Redis
   - Use provisioned concurrency for critical functions

2. **ElastiCache Connection Issues**
   - Ensure Lambda functions are in VPC
   - Check security group configurations

3. **S3 Access Denied**
   - Verify IAM policies and bucket permissions
   - Check object key patterns and lifecycle rules

4. **CloudFront Cache Issues**
   - Create invalidations after deployments
   - Configure appropriate cache behaviors

### Debug Commands
```bash
# Check Terraform state
terraform show

# View CloudWatch logs
aws logs describe-log-groups

# Test Lambda function
aws lambda invoke --function-name container-rce-platform-api response.json
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- AWS for providing robust cloud services
- The Monaco Editor team for the excellent code editor
- The Terraform community for infrastructure as code tools
- React and Node.js communities for amazing frameworks

---

**Built with ❤️ for the cloud-native era**
