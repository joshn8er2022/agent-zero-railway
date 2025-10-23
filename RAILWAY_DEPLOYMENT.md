# Agent Zero Railway Deployment Guide

This guide provides step-by-step instructions for deploying Agent Zero to Railway as a production-ready research service with A2A (Agent-to-Agent) protocol support.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Setup](#detailed-setup)
4. [A2A Endpoint Configuration](#a2a-endpoint-configuration)
5. [Testing the Deployment](#testing-the-deployment)
6. [Integration with Hume DSPy Agent](#integration-with-hume-dspy-agent)
7. [Troubleshooting](#troubleshooting)
8. [Monitoring and Maintenance](#monitoring-and-maintenance)

## Prerequisites

- Railway account (sign up at [railway.app](https://railway.app))
- GitHub account (for repository deployment)
- API keys for LLM providers (OpenAI, Anthropic, etc.)
- Basic understanding of Docker and environment variables

## Quick Start

### 1. Fork or Clone Repository

```bash
# Clone the Agent Zero repository
git clone https://github.com/frdel/agent-zero.git
cd agent-zero

# Or fork it to your own GitHub account
```

### 2. Deploy to Railway

**Option A: Deploy from GitHub (Recommended)**

1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your Agent Zero repository
4. Railway will automatically detect the `Dockerfile` and `railway.toml`

**Option B: Deploy using Railway CLI**

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login to Railway
railway login

# Initialize project
railway init

# Deploy
railway up
```

### 3. Configure Environment Variables

In the Railway dashboard, go to your service → Variables tab and add:

**Required Variables:**
```bash
# LLM Provider (choose one or more)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...

# A2A Authentication Token (generate with: python -c "import secrets; print(secrets.token_hex(32))")
MCP_SERVER_TOKEN=your-secure-token-here

# Flask Secret Key (generate with: python -c "import secrets; print(secrets.token_hex(32))")
FLASK_SECRET_KEY=your-secret-key-here

# A2A Server Configuration
A2A_SERVER_ENABLED=true

# Model Configuration
CHAT_MODEL_PROVIDER=openai
CHAT_MODEL_NAME=gpt-4o
UTIL_MODEL_PROVIDER=openai
UTIL_MODEL_NAME=gpt-4o-mini
```

See `.env.example` for complete list of available variables.

### 4. Add Persistent Storage (Optional but Recommended)

For persistent memory storage:

1. In Railway dashboard, go to your service
2. Click "Variables" → "Add Volume"
3. Mount path: `/app/memory`
4. This ensures Agent Zero's memory persists across deployments

## Detailed Setup

### Understanding the Architecture

Agent Zero on Railway consists of:

```
┌─────────────────────────────────────────┐
│         Railway Service                 │
│  ┌───────────────────────────────────┐  │
│  │   Agent Zero Container            │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Flask Web Server (Port 80) │  │  │
│  │  │  - Web UI                   │  │  │
│  │  │  - API Endpoints            │  │  │
│  │  │  - A2A Endpoint             │  │  │
│  │  └─────────────────────────────┘  │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Agent Zero Core            │  │  │
│  │  │  - LLM Integration          │  │  │
│  │  │  - Tool Execution           │  │  │
│  │  │  - Memory Management        │  │  │
│  │  └─────────────────────────────┘  │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Persistent Storage         │  │  │
│  │  │  /app/memory (Volume)       │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
         ↓                    ↓
    Public URL          Internal URL
  (Web UI Access)    (A2A Communication)
```

### Service Configuration

#### 1. Build Configuration

The `Dockerfile` uses a multi-stage build:
- **Builder stage**: Installs dependencies in a virtual environment
- **Production stage**: Copies only necessary files, runs as non-root user

Key features:
- Optimized for small image size (~1.5GB)
- Includes Playwright for browser automation
- Health check endpoint at `/health`
- Non-root user for security

#### 2. Railway Configuration

The `railway.toml` defines:
- Docker build settings
- Health check configuration
- Restart policy (on failure, max 3 retries)
- Default environment variables

#### 3. Environment Variables

Critical variables to configure:

**LLM Configuration:**
```bash
# Primary model for complex tasks
CHAT_MODEL_PROVIDER=openai
CHAT_MODEL_NAME=gpt-4o
CHAT_MODEL_CTX_LENGTH=128000
CHAT_MODEL_VISION=true

# Utility model for simple tasks (cost optimization)
UTIL_MODEL_PROVIDER=openai
UTIL_MODEL_NAME=gpt-4o-mini
UTIL_MODEL_CTX_LENGTH=128000

# Embedding model for vector search
EMBEDDING_MODEL_PROVIDER=openai
EMBEDDING_MODEL_NAME=text-embedding-3-small
```

**Security Configuration:**
```bash
# Generate secure tokens:
# python -c "import secrets; print(secrets.token_hex(32))"

MCP_SERVER_TOKEN=your-64-char-hex-token
FLASK_SECRET_KEY=your-64-char-hex-token
```

## A2A Endpoint Configuration

### Understanding A2A Protocol

Agent Zero implements the FastA2A protocol for agent-to-agent communication. This allows other AI agents (like Hume DSPy) to delegate complex tasks to Agent Zero.

### A2A Endpoint Structure

The A2A endpoint is available at:

```
https://your-service.railway.app/a2a/t-{TOKEN}/
```

Where `{TOKEN}` is your `MCP_SERVER_TOKEN` value.

### Authentication Methods

Agent Zero supports three authentication methods for A2A:

**1. Token in URL Path (Recommended for Railway)**
```bash
POST https://your-service.railway.app/a2a/t-your-token-here/tasks
```

**2. Bearer Token in Header**
```bash
POST https://your-service.railway.app/a2a/tasks
Authorization: Bearer your-token-here
```

**3. API Key in Header**
```bash
POST https://your-service.railway.app/a2a/tasks
X-API-KEY: your-token-here
```

### A2A Request Format

Example A2A task request:

```json
{
  "message": {
    "role": "user",
    "parts": [
      {
        "kind": "text",
        "text": "Research the latest developments in quantum computing and provide a summary."
      }
    ],
    "kind": "message",
    "message_id": "unique-message-id"
  }
}
```

### A2A Response Format

```json
{
  "task_id": "task-uuid",
  "state": "completed",
  "messages": [
    {
      "role": "agent",
      "parts": [
        {
          "kind": "text",
          "text": "Here is a summary of recent quantum computing developments..."
        }
      ],
      "kind": "message",
      "message_id": "response-message-id"
    }
  ]
}
```

## Testing the Deployment

### 1. Health Check

Verify the service is running:

```bash
curl https://your-service.railway.app/health
```

Expected response:
```json
{"status": "healthy"}
```

### 2. Web UI Access

Open in browser:
```
https://your-service.railway.app/
```

You should see the Agent Zero web interface.

### 3. A2A Endpoint Test

**Test with curl:**

```bash
# Replace YOUR_TOKEN with your MCP_SERVER_TOKEN
curl -X POST https://your-service.railway.app/a2a/t-YOUR_TOKEN/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "Hello, Agent Zero! Can you help me?"}],
      "kind": "message",
      "message_id": "test-123"
    }
  }'
```

**Test with Python:**

```python
import requests
import json

# Configuration
RAILWAY_URL = "https://your-service.railway.app"
TOKEN = "your-mcp-server-token"

# A2A endpoint
url = f"{RAILWAY_URL}/a2a/t-{TOKEN}/tasks"

# Request payload
payload = {
    "message": {
        "role": "user",
        "parts": [
            {
                "kind": "text",
                "text": "Research the top 3 AI frameworks in 2024 and compare them."
            }
        ],
        "kind": "message",
        "message_id": "test-research-001"
    }
}

# Send request
response = requests.post(url, json=payload)

# Print response
print(f"Status: {response.status_code}")
print(f"Response: {json.dumps(response.json(), indent=2)}")
```

### 4. Local Docker Test (Before Railway Deployment)

Test the Docker build locally:

```bash
# Build the image
cd /root/agent-zero
docker build -t agent-zero-railway -f Dockerfile .

# Run the container
docker run -p 50001:80 \
  -e OPENAI_API_KEY=sk-... \
  -e MCP_SERVER_TOKEN=test-token \
  -e A2A_SERVER_ENABLED=true \
  -e CHAT_MODEL_PROVIDER=openai \
  -e CHAT_MODEL_NAME=gpt-4o-mini \
  agent-zero-railway

# Test the A2A endpoint
curl -X POST http://localhost:50001/a2a/t-test-token/tasks \
  -H "Content-Type: application/json" \
  -d '{"message": {"role": "user", "parts": [{"kind": "text", "text": "Hello!"}], "kind": "message", "message_id": "test"}}'
```

## Integration with Hume DSPy Agent

### Internal Network Communication (Recommended)

When both services are on Railway, use internal URLs for fast, secure communication:

```python
# In Hume DSPy Agent code
import requests

class AgentZeroClient:
    def __init__(self):
        # Use Railway internal URL (no public internet)
        self.base_url = "http://agent-zero.railway.internal:80"
        self.token = os.getenv("AGENT_ZERO_TOKEN")
    
    def delegate_research_task(self, task_description: str) -> dict:
        """Delegate a research task to Agent Zero via A2A."""
        url = f"{self.base_url}/a2a/t-{self.token}/tasks"
        
        payload = {
            "message": {
                "role": "user",
                "parts": [
                    {
                        "kind": "text",
                        "text": task_description
                    }
                ],
                "kind": "message",
                "message_id": f"hume-{uuid.uuid4()}"
            }
        }
        
        response = requests.post(url, json=payload, timeout=300)
        return response.json()

# Usage in Hume workflow
agent_zero = AgentZeroClient()
result = agent_zero.delegate_research_task(
    "Research company XYZ and provide competitive analysis"
)
```

### Configuration in Railway

1. **Agent Zero Service:**
   - Set as **private service** (no public URL needed)
   - Internal URL: `agent-zero.railway.internal:80`
   - Environment: `A2A_SERVER_ENABLED=true`

2. **Hume DSPy Service:**
   - Add environment variable: `AGENT_ZERO_URL=http://agent-zero.railway.internal:80`
   - Add environment variable: `AGENT_ZERO_TOKEN=<same-as-agent-zero-mcp-token>`

### Benefits of Internal Network

- **Latency**: <10ms (vs 50-200ms public internet)
- **Security**: No public exposure of A2A endpoint
- **Cost**: No egress charges
- **Reliability**: No internet routing issues

## Troubleshooting

### Common Issues

#### 1. Service Won't Start

**Symptoms:**
- Railway shows "Crashed" status
- Health check fails

**Solutions:**
```bash
# Check Railway logs
railway logs

# Common causes:
# - Missing required environment variables (OPENAI_API_KEY, etc.)
# - Invalid model configuration
# - Port binding issues

# Verify environment variables are set:
railway variables
```

#### 2. A2A Endpoint Returns 401 Unauthorized

**Symptoms:**
- A2A requests fail with 401 status

**Solutions:**
```bash
# Verify token matches in both services
# Agent Zero: MCP_SERVER_TOKEN=abc123
# Hume DSPy: AGENT_ZERO_TOKEN=abc123

# Test with correct token:
curl -X POST https://your-service.railway.app/a2a/t-CORRECT_TOKEN/tasks ...
```

#### 3. A2A Endpoint Returns 503 Service Unavailable

**Symptoms:**
- A2A endpoint returns 503
- Logs show "FastA2A not available"

**Solutions:**
```bash
# Check if A2A is enabled:
A2A_SERVER_ENABLED=true

# Verify fasta2a package is installed (should be in requirements.txt)
# Check Railway build logs for installation errors
```

#### 4. Memory Not Persisting

**Symptoms:**
- Agent Zero forgets previous conversations after restart

**Solutions:**
```bash
# Add Railway volume:
# 1. Go to service → Variables → Add Volume
# 2. Mount path: /app/memory
# 3. Redeploy service

# Verify volume is mounted:
railway run bash
ls -la /app/memory
```

#### 5. High Memory Usage / OOM Errors

**Symptoms:**
- Service crashes with out-of-memory errors
- Railway shows high memory usage

**Solutions:**
```bash
# Upgrade Railway plan for more memory
# Or optimize model configuration:

# Use smaller models:
CHAT_MODEL_NAME=gpt-4o-mini  # Instead of gpt-4o
UTIL_MODEL_NAME=gpt-3.5-turbo  # Instead of gpt-4o-mini

# Reduce context length:
CHAT_MODEL_CTX_LENGTH=32000  # Instead of 128000
```

### Debug Mode

Enable detailed logging:

```bash
# In Railway variables:
LOG_LEVEL=DEBUG

# View logs:
railway logs --follow
```

### Health Check Debugging

Test health endpoint:

```bash
# From Railway shell:
railway run bash
curl http://localhost:80/health

# Check if Flask is running:
ps aux | grep python
netstat -tlnp | grep 80
```

## Monitoring and Maintenance

### Railway Metrics

Monitor in Railway dashboard:
- **CPU Usage**: Should be <50% average
- **Memory Usage**: Should be <80% of allocated
- **Network**: Monitor for unusual spikes
- **Deployments**: Track success/failure rate

### Log Monitoring

```bash
# View real-time logs:
railway logs --follow

# Filter for errors:
railway logs | grep ERROR

# Filter for A2A activity:
railway logs | grep "\[A2A\]"
```

### Performance Optimization

#### 1. Model Selection

```bash
# For cost optimization:
CHAT_MODEL_NAME=gpt-4o-mini  # Cheaper, faster
UTIL_MODEL_NAME=gpt-3.5-turbo  # Very cheap for simple tasks

# For performance:
CHAT_MODEL_NAME=gpt-4o  # Best quality
UTIL_MODEL_NAME=gpt-4o-mini  # Good balance
```

#### 2. Rate Limiting

```bash
# Adjust rate limits to prevent API quota issues:
CHAT_MODEL_RL_REQUESTS=50  # Max requests per minute
CHAT_MODEL_RL_INPUT=50000  # Max input tokens per minute
CHAT_MODEL_RL_OUTPUT=5000  # Max output tokens per minute
```

#### 3. Caching

Agent Zero automatically caches:
- Embedding vectors
- Tool results (when appropriate)
- Model responses (when deterministic)

### Backup and Recovery

#### Memory Backup

```bash
# Download memory volume:
railway run bash
tar -czf memory-backup.tar.gz /app/memory
# Download via Railway dashboard or scp

# Restore memory:
# Upload backup to Railway volume
tar -xzf memory-backup.tar.gz -C /
```

#### Configuration Backup

```bash
# Export environment variables:
railway variables > railway-vars-backup.txt

# Restore:
# Manually re-add variables from backup file
```

### Scaling Considerations

#### Vertical Scaling (More Resources)

- Upgrade Railway plan for more CPU/memory
- Recommended for handling larger models or more concurrent requests

#### Horizontal Scaling (Multiple Instances)

- Not recommended for Agent Zero (stateful service)
- Use load balancing only if implementing shared memory storage

### Cost Optimization

**Estimated Monthly Costs:**

```
Railway Service (Hobby Plan):
- Base: $5/month
- Memory (2GB): ~$3/month
- CPU usage: ~$2/month
Total Railway: ~$10/month

LLM API Costs (varies by usage):
- Light usage (100 requests/day): ~$10-20/month
- Medium usage (500 requests/day): ~$50-100/month
- Heavy usage (2000 requests/day): ~$200-400/month

Total Estimated: $20-410/month depending on usage
```

**Cost Reduction Tips:**

1. Use cheaper models for simple tasks (gpt-3.5-turbo, gpt-4o-mini)
2. Implement request caching
3. Set appropriate rate limits
4. Monitor and optimize prompt lengths
5. Use Railway's free tier for development/testing

## Security Best Practices

### 1. Token Management

```bash
# Generate strong tokens:
python -c "import secrets; print(secrets.token_hex(32))"

# Rotate tokens regularly (every 90 days)
# Update in both Agent Zero and Hume DSPy services
```

### 2. Network Security

```bash
# For production:
# - Keep Agent Zero as private service (no public URL)
# - Only expose via internal Railway network
# - Use Hume DSPy as public-facing gateway

# For development:
# - Use public URL with strong authentication
# - Enable BASIC_AUTH_ENABLED=true
```

### 3. API Key Security

```bash
# Never commit API keys to git
# Use Railway's encrypted environment variables
# Rotate API keys if compromised

# Monitor API usage for anomalies:
# - Check OpenAI/Anthropic dashboards regularly
# - Set up usage alerts
```

### 4. Input Validation

```bash
# Agent Zero validates inputs, but add additional checks in Hume:
# - Sanitize user inputs before sending to Agent Zero
# - Implement rate limiting on Hume side
# - Log all A2A requests for audit
```

## Advanced Configuration

### Custom Prompts

Modify Agent Zero's behavior by customizing prompts:

```bash
# In Railway, add custom prompt files:
# 1. Create custom prompts in /app/prompts/
# 2. Set environment variable:
CUSTOM_PROMPT_PATH=/app/prompts/custom_system.md
```

### Custom Tools

Add custom tools to Agent Zero:

```python
# Create custom tool in /app/python/tools/
# Example: custom_research_tool.py

from python.helpers.tool import Tool, Response

class CustomResearchTool(Tool):
    async def execute(self, **kwargs):
        # Your custom logic here
        return Response(message="Research complete")
```

### MCP Server Integration

Agent Zero also supports MCP (Model Context Protocol):

```bash
# Enable MCP server:
MCP_SERVER_ENABLED=true
MCP_SERVER_HOST=0.0.0.0
MCP_SERVER_PORT=80

# MCP endpoint will be available at:
# https://your-service.railway.app/mcp
```

## Support and Resources

### Documentation

- [Agent Zero GitHub](https://github.com/frdel/agent-zero)
- [Railway Documentation](https://docs.railway.app)
- [FastA2A Protocol](https://github.com/StreetLamb/fasta2a)

### Community

- [Agent Zero Discord](https://discord.gg/agent-zero)
- [Railway Discord](https://discord.gg/railway)

### Getting Help

1. Check Railway logs: `railway logs`
2. Review this troubleshooting guide
3. Search GitHub issues
4. Ask in Discord communities
5. Create GitHub issue with:
   - Railway logs
   - Environment configuration (redact secrets)
   - Steps to reproduce

## Conclusion

You now have Agent Zero deployed on Railway with A2A protocol support! This setup enables:

✅ Production-ready deployment with health checks
✅ A2A endpoint for agent-to-agent communication
✅ Persistent memory storage
✅ Secure token-based authentication
✅ Internal network communication with Hume DSPy
✅ Scalable architecture for research tasks

Next steps:
1. Test the A2A endpoint thoroughly
2. Integrate with Hume DSPy agent
3. Monitor performance and costs
4. Optimize model selection based on usage patterns

Happy deploying! 🚀
