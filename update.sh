#!/bin/bash
# Update script for Rijksmuseum interface
# Pulls latest code, rebuilds Docker container, and restarts the service

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Rijksmuseum Interface Update Script ====${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    echo "Please make sure Docker is installed on your server"
    exit 1
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git is not installed or not in PATH${NC}"
    echo "Please install Git to update from the repository"
    exit 1
fi

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: This doesn't appear to be a Git repository${NC}"
    echo "Please run this script from the root of the Rijksmuseum Interface repository"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please run the setup script first"
    exit 1
fi

# Backup the current .env file
echo -e "${BLUE}Backing up .env file...${NC}"
cp .env .env.backup
echo -e "${GREEN}Backup created: .env.backup${NC}"

# Pull the latest code from Git
echo -e "${BLUE}Pulling latest code from Git...${NC}"
git pull
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to pull updates${NC}"
    echo "Trying to continue anyway..."
else
    echo -e "${GREEN}Successfully pulled latest code${NC}"
fi

# Make sure the HOST variable is correctly set without comments
echo -e "${BLUE}Ensuring HOST variable is correctly set...${NC}"
sed -i 's/^HOST=.*/HOST=0.0.0.0/' .env
grep -q "^HOST=" .env || echo "HOST=0.0.0.0" >> .env
echo -e "${GREEN}HOST setting verified${NC}"

# Extract port and hostname from .env
PORT=$(grep "^PORT=" .env | cut -d '=' -f 2)
PORT=${PORT:-3000} # Default to 3000 if not set
HOSTNAME=$(grep "^HOSTNAME=" .env | cut -d '=' -f 2)

# Check if container exists
echo -e "${BLUE}Checking for existing container...${NC}"
CONTAINER_EXISTS=$(docker ps -a --format '{{.Names}}' | grep -w "rijksmuseum-interface" || echo "")

# Stop existing container if running
if [ -n "$CONTAINER_EXISTS" ]; then
    echo -e "${BLUE}Stopping existing container...${NC}"
    docker stop rijksmuseum-interface
    docker rm rijksmuseum-interface
    echo -e "${GREEN}Removed existing container${NC}"
fi

# Build a new Docker image
echo -e "${BLUE}Building new Docker image...${NC}"
docker build -t rijksmuseum-interface:latest .
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build Docker image${NC}"
    echo "Restoring .env backup..."
    cp .env.backup .env
    exit 1
fi
echo -e "${GREEN}Docker image built successfully${NC}"

# Start the container
echo -e "${BLUE}Starting container...${NC}"
docker run -d \
    --name rijksmuseum-interface \
    -p ${PORT}:${PORT} \
    --env-file .env \
    --restart unless-stopped \
    rijksmuseum-interface:latest

# Check if container started successfully
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start container${NC}"
    echo "Restoring .env backup..."
    cp .env.backup .env
    exit 1
else
    echo -e "${GREEN}Container started successfully!${NC}"
fi

# Wait for container to initialize
echo -e "${BLUE}Waiting for container to initialize...${NC}"
sleep 5

# Display container logs
echo -e "${BLUE}Container logs:${NC}"
docker logs --tail 20 rijksmuseum-interface

echo ""
echo -e "${GREEN}Update completed successfully!${NC}"
echo -e "You can access the application at: ${BLUE}http://YOUR_SERVER_IP:${PORT}${NC}"
if [ -n "$HOSTNAME" ]; then
    echo -e "Or with your domain: ${BLUE}http://${HOSTNAME}${NC}"
fi
