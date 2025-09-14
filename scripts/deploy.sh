#!/bin/bash

# Deployment script for AWS Cloud-Native RCE Platform
set -e

echo "🚀 Starting deployment of AWS Cloud-Native RCE Platform..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
ENVIRONMENT=${ENVIRONMENT:-dev}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure'."
        exit 1
    fi
    
    print_success "All prerequisites are satisfied"
}

# Install Lambda dependencies
install_lambda_dependencies() {
    print_status "Installing Lambda function dependencies..."
    
    # API Lambda
    cd aws-lambda/api
    npm install --production
    cd ../..
    
    # Executor Lambda
    cd aws-lambda/executor
    npm install --production
    cd ../..
    
    print_success "Lambda dependencies installed"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying AWS infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Plan deployment
    print_status "Creating Terraform plan..."
    terraform plan -var="aws_region=${AWS_REGION}" -var="environment=${ENVIRONMENT}" -out=tfplan
    
    # Apply deployment
    print_status "Applying Terraform configuration..."
    terraform apply -auto-approve tfplan
    
    # Get outputs
    print_status "Extracting infrastructure outputs..."
    API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
    CLOUDFRONT_URL=$(terraform output -raw cloudfront_distribution_url)
    S3_FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket)
    
    print_success "Infrastructure deployed successfully"
    
    cd ..
}

# Build and deploy frontend
deploy_frontend() {
    print_status "Building and deploying React frontend..."
    
    # Update environment variables
    cat > .env.production << EOF
REACT_APP_API_BASE_URL=${API_GATEWAY_URL}
REACT_APP_CLOUDFRONT_URL=${CLOUDFRONT_URL}
REACT_APP_ENVIRONMENT=production
GENERATE_SOURCEMAP=false
CI=false
EOF
    
    # Build frontend
    npm run build
    
    # Deploy to S3
    print_status "Uploading frontend to S3..."
    aws s3 sync build/ s3://${S3_FRONTEND_BUCKET} --delete --region ${AWS_REGION}
    
    # Invalidate CloudFront cache
    print_status "Invalidating CloudFront cache..."
    CLOUDFRONT_DISTRIBUTION_ID=$(cd terraform && terraform output -raw cloudfront_distribution_id)
    aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} --paths "/*" --region ${AWS_REGION}
    
    print_success "Frontend deployed successfully"
}

# Main deployment flow
main() {
    print_status "Starting deployment process..."
    
    check_prerequisites
    install_lambda_dependencies
    deploy_infrastructure
    deploy_frontend
    
    print_success "🎉 Deployment completed successfully!"
    print_status "Application URLs:"
    echo "  - CloudFront URL: ${CLOUDFRONT_URL}"
    echo "  - API Gateway URL: ${API_GATEWAY_URL}"
    
    print_warning "Note: It may take a few minutes for CloudFront distribution to be fully available."
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "destroy")
        print_warning "This will destroy all AWS resources. Are you sure? (y/N)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            cd terraform
            terraform destroy -var="aws_region=${AWS_REGION}" -var="environment=${ENVIRONMENT}" -auto-approve
            cd ..
            print_success "Infrastructure destroyed"
        else
            print_status "Destruction cancelled"
        fi
        ;;
    "plan")
        cd terraform
        terraform plan -var="aws_region=${AWS_REGION}" -var="environment=${ENVIRONMENT}"
        cd ..
        ;;
    *)
        echo "Usage: $0 [deploy|destroy|plan]"
        echo "  deploy  - Deploy the complete infrastructure and application (default)"
        echo "  destroy - Destroy all AWS resources"
        echo "  plan    - Show Terraform execution plan"
        exit 1
        ;;
esac
