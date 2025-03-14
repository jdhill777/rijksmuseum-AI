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

# Install dependencies including TypeScript for build
RUN npm install

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
echo -e "${BLUE}Setting up environment variables...${NC}"

# Ask for API keys if not already configured
prompt_for_api_key() {
    local key_name=$1
    local key_var=$2
    local key_url=$3
    local current_value=$(grep -oP "${key_var}=\K[^\s]+" .env 2>/dev/null || echo "")
    
    if [[ -z "$current_value" || "$current_value" == "your_api_key_here" || "$current_value" == "your_"*"_key_here" ]]; then
        echo -e "${YELLOW}${key_name} is required.${NC}"
        echo -e "Get your key from: ${BLUE}${key_url}${NC}"
        read -p "Enter your ${key_name}: " NEW_KEY </dev/tty
        if [[ -n "$NEW_KEY" ]]; then
            if grep -q "${key_var}=" .env 2>/dev/null; then
                sed -i "s|${key_var}=.*|${key_var}=${NEW_KEY}|" .env
            else
                echo "${key_var}=${NEW_KEY}" >> .env
            fi
            echo -e "${GREEN}${key_name} updated${NC}"
        else
            echo -e "${YELLOW}Warning: No ${key_name} provided. The application might not work correctly.${NC}"
        fi
    else
        echo -e "${GREEN}${key_name} already configured${NC}"
    fi
}

# Create a new .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}No .env file found. Creating new configuration...${NC}"
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
fi

# Ensure all required variables are set
prompt_for_api_key "Anthropic API Key" "ANTHROPIC_API_KEY" "https://console.anthropic.com/"
prompt_for_api_key "Rijksmuseum API Key" "RIJKSMUSEUM_API_KEY" "https://data.rijksmuseum.nl/object-metadata/api/"

# Set port configuration
echo -e "${BLUE}Configuring network settings...${NC}"

# Make sure .env file has clean line endings (fix any Windows CRLF issues)
sed -i 's/\r$//' .env

# Get current port values or set defaults - ensure clean extraction
CURRENT_PORT=$(grep -E "^PORT=[0-9]+" .env | cut -d= -f2 | tr -d '\r\n' || echo "3002")
CURRENT_MCP_PORT=$(grep -E "^MCP_PORT=[0-9]+" .env | cut -d= -f2 | tr -d '\r\n' || echo "3003")
CURRENT_HOSTNAME=$(grep -E "^HOSTNAME=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")
CURRENT_ALLOWED_ORIGINS=$(grep -E "^ALLOWED_ORIGINS=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")

# Ensure we have clean integer values for ports
CURRENT_PORT=$(echo "$CURRENT_PORT" | grep -o '^[0-9]*' || echo "3002")
CURRENT_MCP_PORT=$(echo "$CURRENT_MCP_PORT" | grep -o '^[0-9]*' || echo "3003")

echo "${BLUE}Current Configuration:${NC}"
echo "  Web server port: ${YELLOW}${CURRENT_PORT}${NC}"
echo "  MCP server port: ${YELLOW}${CURRENT_MCP_PORT}${NC}"

# Ask for port configuration
read -p "Web server port [${CURRENT_PORT}]: " NEW_PORT </dev/tty
PORT=${NEW_PORT:-$CURRENT_PORT}

read -p "MCP server port [${CURRENT_MCP_PORT}]: " NEW_MCP_PORT </dev/tty
MCP_PORT=${NEW_MCP_PORT:-$CURRENT_MCP_PORT}

# Ask for hostname configuration
echo -e "${YELLOW}Hostname configuration (optional):${NC}"
echo -e "If you're accessing this through a domain name or specific IP, enter it here."
echo -e "This will be used for CORS configuration and access URLs."
read -p "Hostname (e.g., example.com or IP) [${CURRENT_HOSTNAME}]: " NEW_HOSTNAME </dev/tty
HOSTNAME=${NEW_HOSTNAME:-$CURRENT_HOSTNAME}

# Configure ALLOWED_ORIGINS
if [[ -n "$HOSTNAME" ]]; then
    # Build default ALLOWED_ORIGINS with localhost and the hostname
    DEFAULT_ORIGINS="http://localhost:${PORT},http://${HOSTNAME}:${PORT}"
    
    # If hostname doesn't look like an IP address, also add it without port
    if ! [[ $HOSTNAME =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        DEFAULT_ORIGINS+=",http://${HOSTNAME},https://${HOSTNAME}"
    fi
    
    # Ask for allowed origins
    echo -e "${YELLOW}CORS Configuration:${NC}"
    echo -e "Enter comma-separated list of domains allowed to access the API (CORS)"
    read -p "Allowed origins [${DEFAULT_ORIGINS}]: " NEW_ALLOWED_ORIGINS </dev/tty
    ALLOWED_ORIGINS=${NEW_ALLOWED_ORIGINS:-$DEFAULT_ORIGINS}
else
    # Default to localhost only if no hostname
    DEFAULT_ORIGINS="http://localhost:${PORT}"
    read -p "Allowed origins [${DEFAULT_ORIGINS}]: " NEW_ALLOWED_ORIGINS </dev/tty
    ALLOWED_ORIGINS=${NEW_ALLOWED_ORIGINS:-$DEFAULT_ORIGINS}
fi

# Update settings in .env
sed -i "s/^PORT=.*/PORT=${PORT}/" .env
sed -i "s/^MCP_PORT=.*/MCP_PORT=${MCP_PORT}/" .env
sed -i "s/^HOSTNAME=.*/HOSTNAME=${HOSTNAME}/" .env
sed -i "s/^ALLOWED_ORIGINS=.*/ALLOWED_ORIGINS=${ALLOWED_ORIGINS}/" .env

# Set HOST and create MCP_SERVER_URL if missing
sed -i "s/^HOST=.*/HOST=0.0.0.0/" .env

# Use host.docker.internal special DNS name for container-to-host communication
echo -e "${BLUE}Setting up Docker networking...${NC}"
if ! grep -q "MCP_SERVER_URL=" .env; then
    echo "MCP_SERVER_URL=http://host.docker.internal:${MCP_PORT}" >> .env
else
    sed -i "s|^MCP_SERVER_URL=.*|MCP_SERVER_URL=http://host.docker.internal:${MCP_PORT}|" .env
fi
echo -e "${GREEN}Using host.docker.internal for container networking${NC}"

echo -e "${GREEN}Environment configured:${NC}"
echo -e "  Web server port: ${BLUE}${PORT}${NC}"
echo -e "  MCP server port: ${BLUE}${MCP_PORT}${NC}"
echo -e "  Hostname: ${BLUE}${HOSTNAME:-None}${NC}"
echo -e "  Allowed origins: ${BLUE}${ALLOWED_ORIGINS}${NC}"

# Ensure existing containers are stopped and removed
echo -e "${BLUE}Stopping and removing any existing containers...${NC}"
docker stop rijksmuseum-interface rijksmuseum-mcp-server rijksmuseum-ai-interface rijksmuseum-ai-mcp-server 2>/dev/null || true
docker rm rijksmuseum-interface rijksmuseum-mcp-server rijksmuseum-ai-interface rijksmuseum-ai-mcp-server 2>/dev/null || true

# Deploy with docker-compose
echo -e "${BLUE}Building and starting services with docker-compose...${NC}"
docker-compose down || true # Bring down any existing services
docker-compose build --no-cache # Rebuild images to ensure latest code
docker-compose up -d # Start services in detached mode

# Check if services started successfully
if docker ps | grep -q "rijksmuseum-ai-interface" && docker ps | grep -q "rijksmuseum-ai-mcp-server"; then
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
    docker logs --tail 10 rijksmuseum-ai-interface
    
    echo ""
    echo -e "${BLUE}MCP Server Logs:${NC}"
    docker logs --tail 10 rijksmuseum-ai-mcp-server
else
    echo -e "${RED}Error: One or more services failed to start${NC}"
    echo "Please check the logs:"
echo "  docker logs rijksmuseum-ai-interface"
echo "  docker logs rijksmuseum-ai-mcp-server"
fi

echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  View logs: ${YELLOW}docker logs -f rijksmuseum-ai-interface${NC}"
echo -e "  Restart services: ${YELLOW}docker-compose restart${NC}"
echo -e "  Stop services: ${YELLOW}docker-compose down${NC}"
echo -e "  Update and rebuild: ${YELLOW}./deploy-to-unraid.sh${NC}"
