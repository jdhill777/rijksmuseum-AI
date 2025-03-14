#!/bin/bash
# Script to start just the web interface after the MCP server is running

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Rijksmuseum Web Interface Startup ====${NC}"

# Stop any existing web container
echo -e "${YELLOW}Stopping any existing web interface containers...${NC}"
docker stop rijksmuseum-ai-interface 2>/dev/null || true
docker rm rijksmuseum-ai-interface 2>/dev/null || true

# Load environment variables
if [ -f ".env" ]; then
    echo -e "${GREEN}Loading environment variables from .env file${NC}"
    source .env
else
    echo -e "${RED}No .env file found. Please run deploy-to-unraid.sh first.${NC}"
    exit 1
fi

# Set default values if not in .env
PORT=${PORT:-3002}
MCP_PORT=${MCP_PORT:-3003}
ANTHROPIC_API_KEY=$(grep -E "^ANTHROPIC_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")
RIJKSMUSEUM_API_KEY=$(grep -E "^RIJKSMUSEUM_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")

if [[ -z "$ANTHROPIC_API_KEY" || "$ANTHROPIC_API_KEY" == "your_api_key_here" ]]; then
    echo -e "${RED}Error: Anthropic API key not set in .env file${NC}"
    exit 1
fi

if [[ -z "$RIJKSMUSEUM_API_KEY" || "$RIJKSMUSEUM_API_KEY" == "your_rijksmuseum_api_key_here" ]]; then
    echo -e "${RED}Error: Rijksmuseum API key not set in .env file${NC}"
    exit 1
fi

# Check if MCP server is running by testing the port
echo -e "${BLUE}Testing MCP server connection on port ${MCP_PORT}...${NC}"
if nc -z localhost ${MCP_PORT}; then
    echo -e "${GREEN}MCP server appears to be running on port ${MCP_PORT}${NC}"
else
    echo -e "${RED}Warning: MCP server does not appear to be running on port ${MCP_PORT}${NC}"
    echo -e "${YELLOW}Please start the MCP server first with ./start-mcp.sh in a separate terminal${NC}"
    read -p "Continue anyway? (y/n): " CONTINUE </dev/tty
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Start the web interface in foreground mode for debugging
echo -e "${BLUE}Starting web interface on port ${PORT}...${NC}"
NODE_ENV=production \
PORT=${PORT} \
HOST=0.0.0.0 \
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} \
RIJKSMUSEUM_API_KEY=${RIJKSMUSEUM_API_KEY} \
MCP_SERVER_URL=http://localhost:${MCP_PORT} \
node server.js
