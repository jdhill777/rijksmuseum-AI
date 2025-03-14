#!/bin/bash
# Unraid setup script for Rijksmuseum interface Docker container

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Rijksmuseum Interface Docker Setup for Unraid ====${NC}"
echo "This script will help you configure and run the Docker container on Unraid."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    echo "Please make sure Docker is installed on your Unraid server"
    exit 1
fi

# Check if .env file exists, create if not
if [ ! -f .env ]; then
    echo -e "${BLUE}Creating .env file...${NC}"
    cp .env.example .env
    echo -e "${GREEN}Created .env file from template${NC}"
fi

echo -e "${BLUE}Please enter your API keys:${NC}"

# Prompt for API keys if not in .env
ANTHROPIC_KEY=$(grep -oP 'ANTHROPIC_API_KEY=\K[^\s]+' .env || echo "")
if [[ "$ANTHROPIC_KEY" == "" || "$ANTHROPIC_KEY" == "your_api_key_here" ]]; then
    read -p "Enter your Anthropic API key: " ANTHROPIC_KEY
    sed -i "s/ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=${ANTHROPIC_KEY}/" .env
    echo -e "${GREEN}Anthropic API key updated${NC}"
fi

RIJKS_KEY=$(grep -oP 'RIJKSMUSEUM_API_KEY=\K[^\s]+' .env || echo "")
if [[ "$RIJKS_KEY" == "" || "$RIJKS_KEY" == "your_rijksmuseum_api_key_here" ]]; then
    read -p "Enter your Rijksmuseum API key: " RIJKS_KEY
    sed -i "s/RIJKSMUSEUM_API_KEY=.*/RIJKSMUSEUM_API_KEY=${RIJKS_KEY}/" .env
    echo -e "${GREEN}Rijksmuseum API key updated${NC}"
fi

# Configure port
read -p "Enter port to use (default 3000): " PORT
PORT=${PORT:-3000}
sed -i "s/PORT=.*/PORT=${PORT}/" .env
echo -e "${GREEN}Port set to ${PORT}${NC}"

# Configure hostname if needed
read -p "Enter your domain name (leave empty if none): " HOSTNAME
sed -i "s/HOSTNAME=.*/HOSTNAME=${HOSTNAME}/" .env
if [ -n "$HOSTNAME" ]; then
    echo -e "${GREEN}Hostname set to ${HOSTNAME}${NC}"
    # Update ALLOWED_ORIGINS for the domain
    echo "Setting ALLOWED_ORIGINS to include your domain"
    sed -i "s/ALLOWED_ORIGINS=.*/ALLOWED_ORIGINS=http:\/\/localhost:${PORT},https:\/\/${HOSTNAME},http:\/\/${HOSTNAME}/" .env
else
    echo "No hostname set, using default ALLOWED_ORIGINS"
    sed -i "s/ALLOWED_ORIGINS=.*/ALLOWED_ORIGINS=http:\/\/localhost:${PORT}/" .env
fi

echo -e "${BLUE}Starting Docker container...${NC}"
echo "Using docker-compose to build and start the container"

# Run docker-compose
docker-compose up -d

echo ""
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Container started successfully!${NC}"
    echo -e "You can access the application at: ${BLUE}http://YOUR_UNRAID_IP:${PORT}${NC}"
    if [ -n "$HOSTNAME" ]; then
        echo -e "Or with your domain: ${BLUE}http://${HOSTNAME}${NC}"
    fi
    echo ""
    echo -e "${BLUE}Container management commands:${NC}"
    echo "  • Stop container:    docker-compose down"
    echo "  • View logs:         docker-compose logs -f"
    echo "  • Restart:           docker-compose restart"
else
    echo -e "${RED}Failed to start container${NC}"
    echo "Please check the error messages above"
fi
