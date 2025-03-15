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

# Clean up any problematic line endings
sed -i 's/\r$//' .env

# Get current port values or set defaults with clean extraction
PORT=$(grep -E "^PORT=[0-9]+" .env | cut -d= -f2 | tr -d '\r\n' || echo "3002")
MCP_PORT=$(grep -E "^MCP_PORT=[0-9]+" .env | cut -d= -f2 | tr -d '\r\n' || echo "3003")
CURRENT_HOSTNAME=$(grep -E "^HOSTNAME=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")
CURRENT_ALLOWED_ORIGINS=$(grep -E "^ALLOWED_ORIGINS=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")
ANTHROPIC_API_KEY=$(grep -E "^ANTHROPIC_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")
RIJKSMUSEUM_API_KEY=$(grep -E "^RIJKSMUSEUM_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")

# Ensure we have clean integer values for ports
PORT=$(echo "$PORT" | grep -o '^[0-9]*' || echo "3002")
MCP_PORT=$(echo "$MCP_PORT" | grep -o '^[0-9]*' || echo "3003")

# Check API keys first
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

# Display current configuration
echo -e "${BLUE}Current Configuration:${NC}"
echo -e "  Web server port: ${YELLOW}${PORT}${NC}"
echo -e "  MCP server port: ${YELLOW}${MCP_PORT}${NC}"
echo -e "  Hostname: ${YELLOW}${CURRENT_HOSTNAME:-None}${NC}"
echo -e "  Allowed origins: ${YELLOW}${CURRENT_ALLOWED_ORIGINS:-None}${NC}"

# Ask for port configuration
echo -e "${BLUE}Port Configuration:${NC}"
read -p "Web server port [${PORT}]: " NEW_PORT </dev/tty
PORT=${NEW_PORT:-$PORT}

read -p "MCP server port [${MCP_PORT}]: " NEW_MCP_PORT </dev/tty
MCP_PORT=${NEW_MCP_PORT:-$MCP_PORT}

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
echo -e "${BLUE}Updating environment configuration...${NC}"
sed -i "s/^PORT=.*/PORT=${PORT}/" .env
sed -i "s/^MCP_PORT=.*/MCP_PORT=${MCP_PORT}/" .env
sed -i "s/^HOSTNAME=.*/HOSTNAME=${HOSTNAME}/" .env
sed -i "s/^ALLOWED_ORIGINS=.*/ALLOWED_ORIGINS=${ALLOWED_ORIGINS}/" .env
sed -i "s/^HOST=.*/HOST=0.0.0.0/" .env

# Ensure MCP_SERVER_URL is correct for combined container
echo -e "${BLUE}Setting MCP_SERVER_URL to use localhost...${NC}"
sed -i "s|^MCP_SERVER_URL=.*|MCP_SERVER_URL=http://localhost:${MCP_PORT}|" .env

echo -e "${GREEN}Environment configured:${NC}"
echo -e "  Web server port: ${BLUE}${PORT}${NC}"
echo -e "  MCP server port: ${BLUE}${MCP_PORT}${NC}"
echo -e "  Hostname: ${BLUE}${HOSTNAME:-None}${NC}"
echo -e "  Allowed origins: ${BLUE}${ALLOWED_ORIGINS}${NC}"

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
