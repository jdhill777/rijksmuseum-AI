#!/bin/bash
# Start-all script for Rijksmuseum Interface
# This script starts both the MCP server and the main web application

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== Starting Rijksmuseum Interface and MCP Server ====${NC}"

# Load environment variables
if [ -f .env ]; then
    echo -e "${BLUE}Loading environment variables from .env file...${NC}"
    source .env
else
    echo -e "${YELLOW}Warning: .env file not found, using default values${NC}"
fi

# Set default ports if not defined in .env
MCP_PORT=${MCP_PORT:-3003}
PORT=${PORT:-3002}

echo -e "${GREEN}Using ports: Web=${PORT}, MCP=${MCP_PORT}${NC}"

# Ensure MCP Server URL is correctly set
MCP_SERVER_URL="http://localhost:${MCP_PORT}"
sed -i 's|^MCP_SERVER_URL=.*|MCP_SERVER_URL='"${MCP_SERVER_URL}"'|' .env

# Export the variables for child processes
export PORT
export MCP_PORT
export MCP_SERVER_URL

# Check if rijksmuseum-mcp directory exists
if [ ! -d "rijksmuseum-mcp" ]; then
    echo -e "${RED}Error: rijksmuseum-mcp directory not found${NC}"
    echo "Please make sure you are running this script from the main application directory"
    exit 1
fi

# Stop any existing Node.js processes related to our app
echo -e "${BLUE}Stopping any existing processes...${NC}"
pkill -f "node build/index.js" || true
pkill -f "node server.js" || true

# Start MCP server in the background
echo -e "${BLUE}Starting MCP server on port ${MCP_PORT}...${NC}"
cd rijksmuseum-mcp

# Create or update .env file for MCP server
echo "PORT=${MCP_PORT}" > .env
echo "RIJKSMUSEUM_API_KEY=${RIJKSMUSEUM_API_KEY}" >> .env

# Start the MCP server
echo -e "${BLUE}Running MCP server...${NC}"
node build/index.js > mcp-server.log 2>&1 &
MCP_PID=$!

# Check if MCP server started successfully
sleep 3
if ps -p $MCP_PID > /dev/null; then
    echo -e "${GREEN}MCP server started successfully with PID: ${MCP_PID}${NC}"
else
    echo -e "${RED}Failed to start MCP server${NC}"
    cat mcp-server.log
    exit 1
fi

# Go back to the main directory
cd ..

# Start the main application
echo -e "${BLUE}Starting web application on port ${PORT}...${NC}"
node server.js > webapp.log 2>&1 &
WEBAPP_PID=$!

# Check if web application started successfully
sleep 3
if ps -p $WEBAPP_PID > /dev/null; then
    echo -e "${GREEN}Web application started successfully with PID: ${WEBAPP_PID}${NC}"
else
    echo -e "${RED}Failed to start web application${NC}"
    cat webapp.log
    exit 1
fi

# Display access information
echo ""
echo -e "${GREEN}Both services started successfully!${NC}"
echo -e "MCP Server running at: ${BLUE}http://localhost:${MCP_PORT}${NC}"
echo -e "Web Interface running at: ${BLUE}http://localhost:${PORT}${NC}"
echo ""
echo -e "${YELLOW}To stop all services, use: pkill -f 'node build/index.js' && pkill -f 'node server.js'${NC}"
echo -e "${YELLOW}Log files are available at: mcp-server.log and webapp.log${NC}"
