# Multi-stage Dockerfile for Lambda executor with programming language support
FROM public.ecr.aws/lambda/nodejs:20

# Install system dependencies for multiple programming languages
RUN yum update -y && \
    yum groupinstall -y "Development Tools" && \
    yum install -y \
        gcc-c++ \
        java-17-openjdk-devel \
        python3 \
        python3-pip \
        nodejs \
        npm && \
    yum clean all

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# Create symbolic link for python3 as python
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Verify installations
RUN g++ --version && \
    javac -version && \
    python3 --version && \
    node --version

# Copy function code
COPY package*.json ${LAMBDA_TASK_ROOT}
RUN npm install --production

COPY index.js ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD ["index.handler"]
