# Use the official Jenkins LTS image as the base
FROM jenkins/jenkins:lts

# We need to be root to install software
USER root

# Install prerequisites and the Docker CLI
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker repository
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install the Docker CLI
RUN apt-get update && apt-get install -y docker-ce-cli

# Switch back to the default jenkins user
USER jenkins


# Multi-stage build for optimal image size
# Stage 1: Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

# Build application (if needed)
# RUN npm run build

# Stage 2: Runtime stage
FROM node:18-alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy dependencies from builder
COPY --from=builder --chown=appuser:appuser /app/node_modules ./node_modules

# Copy application code
COPY --chown=appuser:appuser . .

# Set environment variables
ENV NODE_ENV=production \
    PORT=8080

# Expose port
EXPOSE 8080

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "server.js"]

# Alternative Dockerfile for Python applications
# FROM python:3.11-slim
# 
# WORKDIR /app
# 
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends gcc && \
#     rm -rf /var/lib/apt/lists/*
# 
# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt
# 
# COPY . .
# 
# RUN useradd -m -u 1000 appuser && \
#     chown -R appuser:appuser /app
# 
# USER appuser
# 
# EXPOSE 8080
# 
# CMD ["python", "app.py"]

# Alternative Dockerfile for Go applications
# FROM golang:1.21-alpine AS builder
# 
# WORKDIR /app
# 
# COPY go.mod go.sum ./
# RUN go mod download
# 
# COPY . .
# 
# RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .
# 
# FROM alpine:latest
# 
# RUN apk --no-cache add ca-certificates
# 
# WORKDIR /root/
# 
# COPY --from=builder /app/main .
# 
# EXPOSE 8080
# 
# CMD ["./main"]