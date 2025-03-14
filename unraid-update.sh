#!/bin/bash
# Unraid update script for Rijksmuseum interface Docker container
# This script pulls the latest code from GitHub, rebuilds the Docker image, and restarts the service

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Rijksmuseum Interface Update Script for Unraid ====${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    echo "Please make sure Docker is installed on your Unraid server"
    exit 1
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git is not installed or not in PATH${NC}"
    echo "Please install Git on your Unraid server"
    exit 1
fi

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: This doesn't appear to be a Git repository${NC}"
    echo "Please run this script from the root of the Rijksmuseum Interface repository"
    exit 1
fi

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes in your repository${NC}"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo "Update aborted"
        exit 0
    fi
fi

echo -e "${BLUE}Updating from GitHub...${NC}"

# Save the current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "Current branch: ${YELLOW}${CURRENT_BRANCH}${NC}"

# Fetch the latest code
echo -e "${BLUE}Fetching latest code...${NC}"
git fetch origin
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to fetch from GitHub${NC}"
    exit 1
fi

# Check if there are updates available
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})
BASE=$(git merge-base @ @{u})

if [ $LOCAL = $REMOTE ]; then
    echo -e "${GREEN}Already up-to-date${NC}"
else
    if [ $LOCAL = $BASE ]; then
        echo -e "${BLUE}Updates available. Pulling changes...${NC}"
        git pull origin $CURRENT_BRANCH
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to pull updates${NC}"
            exit 1
        fi
        echo -e "${GREEN}Successfully pulled latest code${NC}"
    else
        echo -e "${YELLOW}Warning: Your local branch has diverged from the remote branch${NC}"
        read -p "Force pull anyway? This will overwrite local changes (y/n): " FORCE_PULL
        if [[ $FORCE_PULL =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Force pulling changes...${NC}"
            git reset --hard origin/$CURRENT_BRANCH
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to force pull updates${NC}"
                exit 1
            fi
            echo -e "${GREEN}Successfully force pulled latest code${NC}"
        else
            echo "Update aborted"
            exit 0
        fi
    fi
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please run the unraid-setup.sh script first to set up your environment"
    exit 1
fi

# Load environment variables
source .env
PORT=${PORT:-3000}  # Default to port 3000 if not set

# Check if the container exists
CONTAINER_EXISTS=$(docker ps -a --format '{{.Names}}' | grep -w "rijksmuseum-interface" || echo "")

echo -e "${BLUE}Building Docker image...${NC}"
docker build -t rijksmuseum-interface .
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build Docker image${NC}"
    exit 1
fi
echo -e "${GREEN}Docker image built successfully${NC}"

# Stop and remove existing container if it exists
if [ -n "$CONTAINER_EXISTS" ]; then
    echo -e "${BLUE}Stopping existing container...${NC}"
    docker stop rijksmuseum-interface
    docker rm rijksmuseum-interface
    echo -e "${GREEN}Removed old container${NC}"
fi

# Start new container
echo -e "${BLUE}Starting new container...${NC}"
docker run -d \
    --name rijksmuseum-interface \
    -p ${PORT}:${PORT} \
    --env-file .env \
    --restart unless-stopped \
    rijksmuseum-interface

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Container started successfully!${NC}"
    echo -e "You can access the application at: ${BLUE}http://YOUR_UNRAID_IP:${PORT}${NC}"
    if [ -n "$HOSTNAME" ]; then
        echo -e "Or with your domain: ${BLUE}http://${HOSTNAME}${NC}"
    fi
    echo ""
    echo -e "${BLUE}Container logs:${NC}"
    docker logs --tail 10 rijksmuseum-interface
    echo ""
    echo -e "${GREEN}Update completed successfully${NC}"
else
    echo -e "${RED}Failed to start container${NC}"
    echo -e "${YELLOW}Trying to restore previous version...${NC}"
    docker run -d \
        --name rijksmuseum-interface \
        -p ${PORT}:${PORT} \
        --env-file .env \
        --restart unless-stopped \
        rijksmuseum-interface:previous

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Restored previous version${NC}"
    else
        echo -e "${RED}Failed to restore previous version${NC}"
        echo "Please check the error messages above and try running unraid-setup.sh again"
    fi
fi
