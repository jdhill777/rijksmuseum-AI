#!/bin/bash
# Deployment script for Rijksmuseum Art Explorer with MCP server
# This script automatically sets up and deploys both services to Unraid

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Rijksmuseum Art Explorer Complete Deployment ====${NC}"
echo "This script will set up and deploy both the web interface and MCP server."

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker and/or docker-compose not found${NC}"
    echo "Please make sure Docker and docker-compose are installed on your Unraid server"
    exit 1
fi

# Check for required directories and create if needed
echo -e "${BLUE}Checking directory structure...${NC}"
MAIN_DIR=$(pwd)

# Check if rijksmuseum-mcp directory exists
if [ ! -d "rijksmuseum-mcp" ]; then
    echo -e "${YELLOW}MCP server directory not found. Cloning from GitHub...${NC}"
    git clone https://github.com/r-huijts/rijksmuseum-mcp.git
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to clone MCP repository${NC}"
        exit 1
    fi
    echo -e "${GREEN}MCP repository cloned successfully${NC}"
else
    echo -e "${GREEN}MCP server directory found${NC}"
    
    # Update MCP repository if needed
    echo -e "${BLUE}Updating MCP repository...${NC}"
    cd rijksmuseum-mcp
    git pull
    cd $MAIN_DIR
fi

# Create Dockerfile for MCP server if it doesn't exist
echo -e "${BLUE}Creating Dockerfile for MCP server...${NC}"
cat > rijksmuseum-mcp/Dockerfile << 'EOF'
# Dockerfile for Rijksmuseum MCP server

FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy source code and built files
COPY . .

# Build TypeScript if needed
RUN npm run build

# Environment variables
ENV PORT=3003
ENV NODE_ENV=production

# Expose port
EXPOSE ${PORT}

# Start the server
CMD ["node", "build/index.js"]
EOF
echo -e "${GREEN}MCP server Dockerfile created${NC}"

# Configure .env file
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}No .env file found. Creating template...${NC}"
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

# Server hostname (optional, for when behind reverse proxy)
HOSTNAME=
EOF
    
    echo -e "${GREEN}.env file created${NC}"
    echo -e "${YELLOW}Please edit the .env file to add your API keys${NC}"
    read -p "Press Enter to edit the .env file, or Ctrl+C to exit and edit later..." </dev/tty
    nano .env
else
    echo -e "${GREEN}.env file found${NC}"
    
    # Check if the .env file has the required keys
    if ! grep -q "ANTHROPIC_API_KEY" .env || ! grep -q "RIJKSMUSEUM_API_KEY" .env; then
        echo -e "${YELLOW}Warning: Your .env file may be missing required API keys${NC}"
        echo -e "Required keys: ANTHROPIC_API_KEY, RIJKSMUSEUM_API_KEY"
        read -p "Do you want to edit the .env file now? (y/n): " EDIT_ENV </dev/tty
        if [[ $EDIT_ENV =~ ^[Yy]$ ]]; then
            nano .env
        fi
    fi
    
    # Check if MCP_PORT is in the .env file, add if missing
    if ! grep -q "MCP_PORT" .env; then
        echo -e "${YELLOW}Adding MCP_PORT=3003 to .env file${NC}"
        echo "MCP_PORT=3003" >> .env
    fi
fi

# Deploy with docker-compose
echo -e "${BLUE}Building and starting services with docker-compose...${NC}"
docker-compose down || true # Bring down any existing services
docker-compose build --no-cache # Rebuild images to ensure latest code
docker-compose up -d # Start services in detached mode

# Check if services started successfully
if docker ps | grep -q "rijksmuseum-interface" && docker ps | grep -q "rijksmuseum-mcp-server"; then
    echo -e "${GREEN}Services started successfully!${NC}"
    
    # Get server IP for access URL
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}=== Deployment Complete ===${NC}"
    echo -e "Web Interface: ${BLUE}http://${SERVER_IP}:${PORT:-3002}${NC}"
    echo -e "MCP Server: ${BLUE}http://${SERVER_IP}:${MCP_PORT:-3003}${NC}"
    
    # Show container logs
    echo ""
    echo -e "${BLUE}Web Interface Logs:${NC}"
    docker logs --tail 10 rijksmuseum-interface
    
    echo ""
    echo -e "${BLUE}MCP Server Logs:${NC}"
    docker logs --tail 10 rijksmuseum-mcp-server
else
    echo -e "${RED}Error: One or more services failed to start${NC}"
    echo "Please check the logs:"
    echo "  docker logs rijksmuseum-interface"
    echo "  docker logs rijksmuseum-mcp-server"
fi

echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  View logs: ${YELLOW}docker logs -f rijksmuseum-interface${NC}"
echo -e "  Restart services: ${YELLOW}docker-compose restart${NC}"
echo -e "  Stop services: ${YELLOW}docker-compose down${NC}"
echo -e "  Update and rebuild: ${YELLOW}./deploy-to-unraid.sh${NC}"
