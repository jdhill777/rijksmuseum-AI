#!/bin/bash
# Script to forcefully cleanup Unraid directory with fuse_hidden files
# and reinstall the repository properly

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}==== Rijksmuseum Complete Cleanup Script ====${NC}"
echo -e "This script will stop all containers, kill processes using fuse files,"
echo -e "clean up the directory, and set up a fresh installation."

# Backup .env file if it exists
if [[ -f "rijksmuseum-AI/.env" ]]; then
    echo -e "${YELLOW}Backing up your .env file to .env.backup${NC}"
    cp rijksmuseum-AI/.env /tmp/rijksmuseum-env.backup
fi

# Step 1: Stop ALL running Docker containers
echo -e "${BLUE}Stopping all Docker containers...${NC}"
docker stop $(docker ps -a -q) 2>/dev/null || true
docker rm $(docker ps -a -q) 2>/dev/null || true

# Step 2: Find and kill any processes that might have the fuse files open
echo -e "${BLUE}Finding and killing processes that have fuse files open...${NC}"
FUSE_PIDS=$(lsof | grep fuse_hidden | awk '{print $2}' | sort | uniq)
if [[ -n "$FUSE_PIDS" ]]; then
    echo -e "${YELLOW}Found processes using fuse files: $FUSE_PIDS${NC}"
    kill -9 $FUSE_PIDS 2>/dev/null || true
    echo -e "${GREEN}Processes terminated${NC}"
else
    echo -e "${GREEN}No processes found with open handles to fuse files${NC}"
fi

# Step 3: Force unmount any filesystem mounts that might be causing issues
echo -e "${BLUE}Checking for any problematic mounts...${NC}"
if mount | grep "/mnt/user/appdata/rijksmuseum-AI"; then
    echo -e "${YELLOW}Found mount points, attempting to umount${NC}"
    umount -f /mnt/user/appdata/rijksmuseum-AI 2>/dev/null || true
fi

# Step 4: Remove the directory completely using stronger methods
echo -e "${BLUE}Removing rijksmuseum-AI directory completely...${NC}"

# First try to remove any fuse_hidden files specifically
find /mnt/user/appdata/rijksmuseum-AI -name ".fuse_hidden*" -exec rm -f {} \; 2>/dev/null

# Try to force remove the entire directory with different methods
cd /mnt/user/appdata
echo -e "${YELLOW}Removing directory with rm -rf${NC}"
rm -rf rijksmuseum-AI/ 2>/dev/null || true

# If that doesn't work, try with find
if [[ -d "rijksmuseum-AI" ]]; then
    echo -e "${YELLOW}Trying alternative removal with find...${NC}"
    find rijksmuseum-AI -type f -exec rm -f {} \; 2>/dev/null
    find rijksmuseum-AI -type d -delete 2>/dev/null
fi

# As a last resort, try with unlink
if [[ -d "rijksmuseum-AI" ]]; then
    echo -e "${YELLOW}Using unlink for stubborn files...${NC}"
    find rijksmuseum-AI -type f -exec unlink {} \; 2>/dev/null
    rm -rf rijksmuseum-AI 2>/dev/null || true
fi

# Verify if directory is gone
if [[ -d "rijksmuseum-AI" ]]; then
    echo -e "${RED}Failed to remove directory completely. Please try to reboot Unraid.${NC}"
    exit 1
else
    echo -e "${GREEN}Directory successfully removed${NC}"
fi

# Step 5: Clone the repository fresh
echo -e "${BLUE}Cloning fresh repository...${NC}"
git clone https://github.com/jdhill777/rijksmuseum-AI.git
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to clone repository${NC}"
    exit 1
fi

# Step 6: Restore .env file if backup exists
if [[ -f "/tmp/rijksmuseum-env.backup" ]]; then
    echo -e "${GREEN}Restoring .env file from backup${NC}"
    cp /tmp/rijksmuseum-env.backup rijksmuseum-AI/.env
    rm /tmp/rijksmuseum-env.backup
fi

# Step 7: Set up permissions
echo -e "${BLUE}Setting up permissions...${NC}"
cd rijksmuseum-AI
chmod +x *.sh

# Step 8: Run the fixed module script
echo -e "${BLUE}Running the fixed module script...${NC}"
./fix-module-issue.sh

echo -e "\n${BOLD}${GREEN}CLEANUP COMPLETE!${NC}"
echo -e "Your Rijksmuseum application should now be running with the fixed configuration."
echo -e "You can check the logs with: ${YELLOW}docker logs rijksmuseum-combined${NC}"
