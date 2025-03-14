#!/bin/bash
# Script to fix the .env file issue with comments in HOST variable

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Fixing .env file for Rijksmuseum Interface ====${NC}"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please run this script from the root directory of the Rijksmuseum Interface"
    exit 1
fi

# Display current HOST line
echo -e "${BLUE}Current HOST setting in .env:${NC}"
grep "^HOST=" .env || echo "HOST setting not found!"

# Fix the HOST variable - remove any comments
sed -i 's/HOST=0\.0\.0\.0.*$/HOST=0.0.0.0/' .env

# Display the fixed line
echo -e "${GREEN}Updated HOST setting:${NC}"
grep "^HOST=" .env

echo -e "${BLUE}Restarting Docker container...${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    echo "You'll need to restart the container manually."
    exit 1
fi

# Check if the container exists
if docker ps -a --format '{{.Names}}' | grep -q "rijksmuseum-interface"; then
    echo "Restarting rijksmuseum-interface container..."
    docker restart rijksmuseum-interface
    echo -e "${GREEN}Container restarted!${NC}"
    
    # Show container logs
    echo -e "${BLUE}Latest container logs:${NC}"
    docker logs --tail 20 rijksmuseum-interface
else
    echo -e "${RED}Container 'rijksmuseum-interface' not found!${NC}"
    echo "You might need to run the setup script again."
fi

echo -e "${GREEN}Fix completed!${NC}"
