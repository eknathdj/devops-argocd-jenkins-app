#!/bin/bash

set -e

echo "=== DevOps Pipeline Testing ==="
echo ""

# Test 1: Docker Build
echo "Test 1: Building Docker image locally..."
docker build -t test-app:local .
if [ $? -eq 0 ]; then
    echo "✓ Docker build successful"
else
    echo "✗ Docker build failed"
    exit 1
fi

# Test 2: Run container
echo ""
echo "Test 2: Running container..."
docker run -d --name test-app -p 8080:8080 test-app:local
sleep 5

# Test 3: Health check
echo ""
echo "Test 3: Testing health endpoint..."
response=$(curl -s http://localhost:8080/health)
if [[ $response == *"healthy"* ]]; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
    docker stop test-app
    docker rm test-app
    exit 1
fi

# Cleanup
echo ""
echo "Cleaning up..."
docker stop test-app
docker rm test-app
docker rmi test-app:local

echo ""
echo "=== All tests passed! ==="