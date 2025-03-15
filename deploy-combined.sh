#!/bin/bash
# Deployment script for combined Rijksmuseum container (both app and MCP server)
# This combined approach eliminates network issues between containers

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}==== Rijksmuseum Combined Container Deployment ====${NC}"
echo "This script will set up and deploy both the web interface and MCP server"
echo "in a single container to eliminate networking issues."

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker and/or docker-compose not found${NC}"
    echo "Please make sure Docker and docker-compose are installed on your Unraid server"
    exit 1
fi

# Load environment variables or set up .env file
if [ -f ".env" ]; then
    echo -e "${GREEN}Loading environment variables from .env file${NC}"
    source .env
else
    echo -e "${RED}No .env file found. Creating default .env file...${NC}"
    cat > .env << EOF
# Rijksmuseum Art Explorer configuration

# API Keys - REQUIRED
# Get Anthropic API key from: https://console.anthropic.com/
ANTHROPIC_API_KEY=your_api_key_here
# Get Rijksmuseum API key from: https://data.rijksmuseum.nl/object-metadata/api/
RIJKSMUSEUM_API_KEY=your_rijksmuseum_api_key_here

# Port Configuration
PORT=3002
MCP_PORT=3003

# Network Configuration
HOST=0.0.0.0
ALLOWED_ORIGINS=http://localhost:3002

# MCP Server URL - Critical for communication
MCP_SERVER_URL=http://localhost:3003

# Server hostname (optional, for when behind reverse proxy)
HOSTNAME=
EOF
    echo -e "${YELLOW}Please edit the .env file to set your API keys${NC}"
    read -p "Press Enter to edit the .env file, or Ctrl+C to exit..." </dev/tty
    ${EDITOR:-nano} .env
fi

# Set default values from .env file
PORT=${PORT:-3002}
MCP_PORT=${MCP_PORT:-3003}
ANTHROPIC_API_KEY=$(grep -E "^ANTHROPIC_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")
RIJKSMUSEUM_API_KEY=$(grep -E "^RIJKSMUSEUM_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")

# Check API keys
if [[ -z "$ANTHROPIC_API_KEY" || "$ANTHROPIC_API_KEY" == "your_api_key_here" ]]; then
    echo -e "${RED}Error: Anthropic API key not set in .env file${NC}"
    read -p "Enter your Anthropic API key: " ANTHROPIC_API_KEY </dev/tty
    sed -i "s/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}/" .env
fi

if [[ -z "$RIJKSMUSEUM_API_KEY" || "$RIJKSMUSEUM_API_KEY" == "your_rijksmuseum_api_key_here" ]]; then
    echo -e "${RED}Error: Rijksmuseum API key not set in .env file${NC}"
    read -p "Enter your Rijksmuseum API key: " RIJKSMUSEUM_API_KEY </dev/tty
    sed -i "s/^RIJKSMUSEUM_API_KEY=.*/RIJKSMUSEUM_API_KEY=${RIJKSMUSEUM_API_KEY}/" .env
fi

# Ensure MCP_SERVER_URL is correct
echo -e "${BLUE}Setting MCP_SERVER_URL to use localhost...${NC}"
sed -i "s|^MCP_SERVER_URL=.*|MCP_SERVER_URL=http://localhost:${MCP_PORT}|" .env

# Stop any existing containers with the same names
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker stop rijksmuseum-combined rijksmuseum-interface rijksmuseum-mcp-server 2>/dev/null || true
docker rm rijksmuseum-combined rijksmuseum-interface rijksmuseum-mcp-server 2>/dev/null || true

# Make sure combined-startup.sh has execute permissions
chmod +x combined-startup.sh

# Build and start the combined container
echo -e "${BLUE}Building and starting combined container...${NC}"
docker-compose -f docker-compose.combined.yml down || true
docker-compose -f docker-compose.combined.yml build --no-cache
docker-compose -f docker-compose.combined.yml up -d

# Check if container started successfully
if docker ps | grep -q "rijksmuseum-combined"; then
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "${BOLD}${GREEN}=== Deployment Complete ===${NC}"
    echo -e "Web Interface: ${BLUE}http://${SERVER_IP}:${PORT:-3002}${NC}"
    echo -e "MCP Server (internal): ${BLUE}http://localhost:${MCP_PORT:-3003}${NC}"
    
    # Show logs
    echo -e "${YELLOW}Container logs:${NC}"
    docker logs --tail 10 rijksmuseum-combined
    
    echo ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "  View logs: ${YELLOW}docker logs -f rijksmuseum-combined${NC}"
    echo -e "  Restart container: ${YELLOW}docker-compose -f docker-compose.combined.yml restart${NC}"
    echo -e "  Stop container: ${YELLOW}docker-compose -f docker-compose.combined.yml down${NC}"
    echo -e "  Update and rebuild: ${YELLOW}./deploy-combined.sh${NC}"
else
    echo -e "${RED}Error: Combined container failed to start${NC}"
    echo -e "Please check the logs: ${YELLOW}docker logs rijksmuseum-combined${NC}"
fi
