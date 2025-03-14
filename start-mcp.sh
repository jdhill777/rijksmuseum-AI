#!/bin/bash
# Script to start and test the MCP server

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Rijksmuseum MCP Server Startup ====${NC}"

# Stop any existing MCP server container
echo -e "${YELLOW}Stopping any existing MCP server containers...${NC}"
docker stop rijksmuseum-ai-mcp-server 2>/dev/null || true
docker rm rijksmuseum-ai-mcp-server 2>/dev/null || true

# Load environment variables
if [ -f ".env" ]; then
    echo -e "${GREEN}Loading environment variables from .env file${NC}"
    source .env
else
    echo -e "${RED}No .env file found. Please run deploy-to-unraid.sh first.${NC}"
    exit 1
fi

MCP_PORT=${MCP_PORT:-3003}
RIJKSMUSEUM_API_KEY=$(grep -E "^RIJKSMUSEUM_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")

if [[ -z "$RIJKSMUSEUM_API_KEY" || "$RIJKSMUSEUM_API_KEY" == "your_rijksmuseum_api_key_here" ]]; then
    echo -e "${RED}Error: Rijksmuseum API key not set in .env file${NC}"
    exit 1
fi

# Start MCP server in foreground to debug issues
echo -e "${BLUE}Starting MCP server on port ${MCP_PORT}...${NC}"
cd rijksmuseum-mcp
PORT=${MCP_PORT} RIJKSMUSEUM_API_KEY=${RIJKSMUSEUM_API_KEY} node build/index.js
