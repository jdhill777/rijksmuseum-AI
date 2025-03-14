#!/bin/bash
# Script to fix the Docker container issue with HOST variable

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Fixing Docker Container for Rijksmuseum Interface ====${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    echo "Please make sure Docker is installed on your Unraid server"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please run this script from the root directory of the Rijksmuseum Interface"
    exit 1
fi

# Fix the HOST variable in the .env file (again to be sure)
echo -e "${BLUE}Fixing HOST variable in .env file...${NC}"
sed -i 's/HOST=0\.0\.0\.0.*$/HOST=0.0.0.0/' .env
echo -e "${GREEN}Updated HOST setting in .env file${NC}"

# Create a temporary Dockerfile.fix with explicit HOST setting
echo -e "${BLUE}Creating a temporary Dockerfile with explicit HOST setting...${NC}"
cat > Dockerfile.fix << EOF
# Use the original Dockerfile
FROM $(grep "^FROM" Dockerfile | head -1 | cut -d ' ' -f 2-)

# Copy application files
COPY . /app
WORKDIR /app

# Install dependencies
RUN npm install

# Set environment variables explicitly
ENV HOST=0.0.0.0
ENV PORT=3000

# Expose the port
EXPOSE \${PORT}

# Start the application
CMD ["node", "server.js"]
EOF

echo -e "${GREEN}Created temporary Dockerfile.fix${NC}"

# Stop and remove existing container
echo -e "${BLUE}Stopping and removing existing container...${NC}"
docker stop rijksmuseum-interface 2>/dev/null || true
docker rm rijksmuseum-interface 2>/dev/null || true

# Build new Docker image with the fixed Dockerfile
echo -e "${BLUE}Building new Docker image...${NC}"
docker build -t rijksmuseum-interface:fixed -f Dockerfile.fix .

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to build Docker image${NC}"
    rm Dockerfile.fix
    exit 1
fi

# Extract port and other variables from .env
PORT=$(grep "^PORT=" .env | cut -d '=' -f 2)
PORT=${PORT:-3000}
HOSTNAME=$(grep "^HOSTNAME=" .env | cut -d '=' -f 2)

# Start the container with the fixed image
echo -e "${BLUE}Starting container with fixed image...${NC}"
docker run -d \
    --name rijksmuseum-interface \
    -p ${PORT}:${PORT} \
    --env-file .env \
    -e HOST=0.0.0.0 \
    --restart unless-stopped \
    rijksmuseum-interface:fixed

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start Docker container${NC}"
    rm Dockerfile.fix
    exit 1
fi

echo -e "${GREEN}Container started with fixed image${NC}"

# Display the logs after a short delay
echo -e "${BLUE}Waiting for container to start...${NC}"
sleep 5
echo -e "${BLUE}Container logs:${NC}"
docker logs rijksmuseum-interface

# Clean up
rm Dockerfile.fix
echo -e "${GREEN}Temporary Dockerfile removed${NC}"

echo -e "${GREEN}Fix completed!${NC}"
echo ""
echo -e "You can access the application at: ${BLUE}http://YOUR_UNRAID_IP:${PORT}${NC}"
if [ -n "$HOSTNAME" ]; then
    echo -e "Or with your domain: ${BLUE}http://${HOSTNAME}${NC}"
fi
