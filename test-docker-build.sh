#!/bin/bash

# Test script for Agent Zero Railway Docker build
# This script builds and tests the Docker image locally before Railway deployment

set -e  # Exit on error

echo "========================================"
echo "Agent Zero Railway Docker Build Test"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="agent-zero-railway"
CONTAINER_NAME="agent-zero-test"
TEST_PORT="50001"
TEST_TOKEN="test-token-$(date +%s)"

echo "${YELLOW}Step 1: Building Docker image...${NC}"
if docker build -t $IMAGE_NAME -f Dockerfile . ; then
    echo "${GREEN}✓ Docker image built successfully${NC}"
else
    echo "${RED}✗ Docker build failed${NC}"
    exit 1
fi

echo ""
echo "${YELLOW}Step 2: Checking image size...${NC}"
IMAGE_SIZE=$(docker images $IMAGE_NAME --format "{{.Size}}")
echo "Image size: $IMAGE_SIZE"

echo ""
echo "${YELLOW}Step 3: Starting container (this may take 30-40 seconds)...${NC}"
echo "Note: Container will start in background. Use 'docker logs -f $CONTAINER_NAME' to view logs."

# Stop and remove existing container if it exists
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Start container with minimal configuration
docker run -d \
  --name $CONTAINER_NAME \
  -p $TEST_PORT:80 \
  -e MCP_SERVER_TOKEN=$TEST_TOKEN \
  -e A2A_SERVER_ENABLED=true \
  -e CHAT_MODEL_PROVIDER=openai \
  -e CHAT_MODEL_NAME=gpt-4o-mini \
  -e OPENAI_API_KEY=${OPENAI_API_KEY:-sk-test} \
  $IMAGE_NAME

if [ $? -eq 0 ]; then
    echo "${GREEN}✓ Container started successfully${NC}"
else
    echo "${RED}✗ Container failed to start${NC}"
    exit 1
fi

echo ""
echo "${YELLOW}Step 4: Waiting for service to be ready (40 seconds)...${NC}"
sleep 40

echo ""
echo "${YELLOW}Step 5: Testing health endpoint...${NC}"
if curl -f http://localhost:$TEST_PORT/health 2>/dev/null; then
    echo ""
    echo "${GREEN}✓ Health endpoint responding${NC}"
else
    echo ""
    echo "${RED}✗ Health endpoint not responding${NC}"
    echo "Container logs:"
    docker logs $CONTAINER_NAME --tail 50
    exit 1
fi

echo ""
echo "${YELLOW}Step 6: Testing A2A endpoint...${NC}"
A2A_RESPONSE=$(curl -s -X POST http://localhost:$TEST_PORT/a2a/t-$TEST_TOKEN/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "Hello, Agent Zero! This is a test."}],
      "kind": "message",
      "message_id": "test-123"
    }
  }' 2>/dev/null)

if [ -n "$A2A_RESPONSE" ]; then
    echo "${GREEN}✓ A2A endpoint responding${NC}"
    echo "Response preview: $(echo $A2A_RESPONSE | head -c 100)..."
else
    echo "${RED}✗ A2A endpoint not responding${NC}"
    echo "Container logs:"
    docker logs $CONTAINER_NAME --tail 50
    exit 1
fi

echo ""
echo "${YELLOW}Step 7: Checking container health...${NC}"
CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' $CONTAINER_NAME)
if [ "$CONTAINER_STATUS" = "running" ]; then
    echo "${GREEN}✓ Container is running${NC}"
else
    echo "${RED}✗ Container is not running (status: $CONTAINER_STATUS)${NC}"
    exit 1
fi

echo ""
echo "========================================"
echo "${GREEN}All tests passed! ✓${NC}"
echo "========================================"
echo ""
echo "Container Information:"
echo "  Name: $CONTAINER_NAME"
echo "  Port: $TEST_PORT"
echo "  Token: $TEST_TOKEN"
echo ""
echo "Useful commands:"
echo "  View logs:     docker logs -f $CONTAINER_NAME"
echo "  Stop:          docker stop $CONTAINER_NAME"
echo "  Remove:        docker rm $CONTAINER_NAME"
echo "  Shell access:  docker exec -it $CONTAINER_NAME bash"
echo ""
echo "Test URLs:"
echo "  Health:        http://localhost:$TEST_PORT/health"
echo "  Web UI:        http://localhost:$TEST_PORT/"
echo "  A2A endpoint:  http://localhost:$TEST_PORT/a2a/t-$TEST_TOKEN/"
echo ""
echo "${YELLOW}Note: Container is still running. Stop it when done testing.${NC}"
