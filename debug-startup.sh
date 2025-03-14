#!/bin/bash
# Comprehensive debugging script for Rijksmuseum application
# This script runs both services in sequence with port checks and debugging

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}==== Rijksmuseum Application Debug Startup ====${NC}"
echo "This script will stop all existing containers and run both services"
echo "directly without Docker to debug connectivity issues."

# Check for nc (netcat) utility which is needed for port checking
if ! command -v nc &> /dev/null; then
    echo -e "${YELLOW}Warning: 'nc' (netcat) not found. Port checking will be skipped.${NC}"
    echo "You can install it with: apt-get install netcat"
    HAS_NETCAT=false
else
    HAS_NETCAT=true
fi

# Stop all existing containers
echo -e "${YELLOW}Stopping all existing containers...${NC}"
docker stop rijksmuseum-interface rijksmuseum-mcp-server \
           rijksmuseum-ai-interface rijksmuseum-ai-mcp-server 2>/dev/null || true
docker rm rijksmuseum-interface rijksmuseum-mcp-server \
          rijksmuseum-ai-interface rijksmuseum-ai-mcp-server 2>/dev/null || true

# Load environment variables
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
    source .env
fi

# Set default values if not in .env
PORT=${PORT:-3002}
MCP_PORT=${MCP_PORT:-3003}
ANTHROPIC_API_KEY=$(grep -E "^ANTHROPIC_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")
RIJKSMUSEUM_API_KEY=$(grep -E "^RIJKSMUSEUM_API_KEY=" .env | cut -d= -f2 | tr -d '\r\n' || echo "")

# Check if API keys are set
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

# Make sure the MCP_SERVER_URL is correctly set in .env
echo -e "${BLUE}Ensuring MCP_SERVER_URL is correct...${NC}"
sed -i "s|^MCP_SERVER_URL=.*|MCP_SERVER_URL=http://localhost:${MCP_PORT}|" .env

# Check if ports are already in use
check_port() {
    if [ "$HAS_NETCAT" = true ]; then
        if nc -z localhost $1 2>/dev/null; then
            echo -e "${RED}Error: Port $1 is already in use.${NC}"
            echo "Please stop any services using this port and try again."
            read -p "Press Enter to continue anyway, or Ctrl+C to exit..." </dev/tty
        else
            echo -e "${GREEN}Port $1 is available.${NC}"
        fi
    fi
}

echo -e "${BLUE}Checking if ports are available...${NC}"
check_port $MCP_PORT
check_port $PORT

# Create test script to verify connectivity
echo -e "${BLUE}Creating connectivity test script...${NC}"
cat > test-connectivity.js << EOF
const fetch = require('node-fetch');
const http = require('http');

// Get MCP port from environment or use default
const MCP_PORT = process.env.MCP_PORT || 3003;
const MCP_URL = \`http://localhost:\${MCP_PORT}/api/tools/search_artwork\`;

console.log(\`Testing connectivity to MCP server at \${MCP_URL}...\`);

// Create a simple HTTP server for verification
const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('Connectivity test server running');
});

// Start the server on a random port
server.listen(0, 'localhost', async () => {
  const address = server.address();
  console.log(\`Test server listening on port \${address.port}\`);
  
  try {
    // Test connection to MCP server
    console.log('Attempting to connect to MCP server...');
    const response = await fetch(MCP_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query: 'test',
        pageSize: 1
      }),
      timeout: 5000 // 5 second timeout
    });
    
    console.log(\`Response status: \${response.status}\`);
    if (response.ok) {
      console.log('✅ Successfully connected to MCP server!');
      const data = await response.json();
      console.log('Response data:', JSON.stringify(data).substring(0, 100) + '...');
    } else {
      console.log('❌ Connected to server but received error response');
      console.log(await response.text());
    }
  } catch (error) {
    console.log('❌ Failed to connect to MCP server');
    console.error('Error details:', error);
  }
  
  // Close the test server
  server.close(() => {
    console.log('Test complete');
    process.exit(0);
  });
});
EOF

# Start MCP server in the background
echo -e "${BOLD}${BLUE}Starting MCP server on port ${MCP_PORT}...${NC}"
cd rijksmuseum-mcp
echo -e "${YELLOW}Building TypeScript if needed...${NC}"
npm run build
echo -e "${GREEN}Build complete. Starting MCP server...${NC}"
PORT=${MCP_PORT} RIJKSMUSEUM_API_KEY=${RIJKSMUSEUM_API_KEY} node build/index.js > ../mcp-server.log 2>&1 &
MCP_PID=$!
cd ..

echo -e "${GREEN}MCP server started with PID ${MCP_PID}${NC}"
echo -e "${YELLOW}Waiting 5 seconds for MCP server to initialize...${NC}"
sleep 5

# Check if MCP server is running
if kill -0 $MCP_PID 2>/dev/null; then
    echo -e "${GREEN}MCP server is running${NC}"
    
    # Test connectivity to MCP server
    echo -e "${BLUE}Testing connectivity to MCP server...${NC}"
    if [ -f "node_modules/node-fetch/package.json" ]; then
        node test-connectivity.js
    else
        echo -e "${YELLOW}node-fetch not installed, skipping connectivity test${NC}"
        echo -e "${YELLOW}You can install it with: npm install node-fetch${NC}"
    fi
    
    # Start the web interface
    echo -e "${BOLD}${BLUE}Starting web interface on port ${PORT}...${NC}"
    NODE_ENV=production \
    PORT=${PORT} \
    HOST=0.0.0.0 \
    ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} \
    RIJKSMUSEUM_API_KEY=${RIJKSMUSEUM_API_KEY} \
    MCP_SERVER_URL=http://localhost:${MCP_PORT} \
    node server.js > web-interface.log 2>&1 &
    WEB_PID=$!
    
    echo -e "${GREEN}Web interface started with PID ${WEB_PID}${NC}"
    echo -e "${YELLOW}Waiting 3 seconds for web interface to initialize...${NC}"
    sleep 3
    
    # Final status
    if kill -0 $MCP_PID 2>/dev/null && kill -0 $WEB_PID 2>/dev/null; then
        echo -e "${BOLD}${GREEN}Both services are running successfully!${NC}"
        echo -e "MCP Server: ${BLUE}http://localhost:${MCP_PORT}${NC} (PID: ${MCP_PID})"
        echo -e "Web Interface: ${BLUE}http://localhost:${PORT}${NC} (PID: ${WEB_PID})"
        echo ""
        echo -e "${YELLOW}To stop the services, run:${NC}"
        echo -e "  kill ${MCP_PID} ${WEB_PID}"
        echo ""
        echo -e "${YELLOW}To view logs:${NC}"
        echo -e "  MCP Server: ${BLUE}tail -f mcp-server.log${NC}"
        echo -e "  Web Interface: ${BLUE}tail -f web-interface.log${NC}"
    else
        echo -e "${RED}One or more services failed to start${NC}"
        echo -e "Please check the logs for details:"
        echo -e "  MCP Server: ${BLUE}cat mcp-server.log${NC}"
        echo -e "  Web Interface: ${BLUE}cat web-interface.log${NC}"
    fi
else
    echo -e "${RED}MCP server failed to start. Check mcp-server.log for details.${NC}"
    cat mcp-server.log
fi
