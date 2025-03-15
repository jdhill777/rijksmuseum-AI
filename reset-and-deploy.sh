#!/bin/bash
# Script to reset local git state, pull latest changes, and deploy the combined container

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}==== Rijksmuseum Reset and Deploy Script ====${NC}"
echo "This script will reset your local repository state, pull the latest"
echo "changes, and deploy the combined container solution."

# Make sure we're in the right directory
if [[ ! -f "deploy-combined.sh" ]]; then
    echo -e "${RED}Error: deploy-combined.sh not found.${NC}"
    echo "Please run this script from the root of the rijksmuseum-AI repository."
    exit 1
fi

# Backup .env file if it exists
if [[ -f ".env" ]]; then
    echo -e "${YELLOW}Backing up your .env file to .env.backup${NC}"
    cp .env .env.backup
fi

# Reset local git state
echo -e "${BLUE}Resetting local git state...${NC}"
git fetch origin
git reset --hard origin/main
git clean -fd # Remove untracked files and directories

# Check if backup .env exists and restore it
if [[ -f ".env.backup" ]]; then
    echo -e "${GREEN}Restoring your .env file from backup${NC}"
    cp .env.backup .env
fi

# Ensure script has execute permissions
echo -e "${BLUE}Setting execute permissions on scripts...${NC}"
chmod +x deploy-combined.sh combined-startup.sh

# Run the combined deploy script
echo -e "${BOLD}${BLUE}Running deployment script...${NC}"
./deploy-combined.sh
