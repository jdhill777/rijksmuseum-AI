#!/bin/bash
# Direct fix for PM2 and ES modules compatibility issue
# Run this script on your Unraid server where the container is deployed

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}==== Rijksmuseum ES Module Compatibility Fix ====${NC}"
echo "This script will fix the PM2 and ES module compatibility issues directly."

# Stop any existing containers
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker stop rijksmuseum-combined rijksmuseum-ai-interface rijksmuseum-ai-mcp-server 2>/dev/null || true

# Create a temporary Dockerfile to fix the issue
echo -e "${BLUE}Creating a fixed Dockerfile...${NC}"
cat > Dockerfile.fix << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Install process manager
RUN npm install -g pm2

# Copy web app files
COPY package*.json ./
COPY server.js ./
COPY index.html ./
COPY css/ ./css/
COPY js/ ./js/
COPY favicon* ./
COPY apple-touch-icon.png ./

# Install web app dependencies
RUN npm install --production

# Fix package.json to use CommonJS
RUN if grep -q '"type"' package.json; then \
    sed -i 's/"type"[[:space:]]*:[[:space:]]*"module"/"type": "commonjs"/g' package.json; \
  else \
    sed -i '/"name"/a \ \ "type": "commonjs",' package.json; \
  fi

# Create MCP server directory
WORKDIR /app/rijksmuseum-mcp

# Copy MCP server files
COPY rijksmuseum-mcp/package*.json ./
COPY rijksmuseum-mcp/tsconfig.json ./
COPY rijksmuseum-mcp/src/ ./src/

# Install MCP server dependencies and build
RUN npm install
RUN npm run build

# Create startup script
WORKDIR /app

# Create startup script
RUN echo '#!/bin/sh' > start.sh && \
    echo 'echo "Starting Rijksmuseum services..."' >> start.sh && \
    echo 'echo "Web server port: $PORT"' >> start.sh && \
    echo 'echo "MCP server port: $MCP_PORT"' >> start.sh && \
    echo 'echo "MCP server URL: $MCP_SERVER_URL"' >> start.sh && \
    echo '' >> start.sh && \
    echo '# Create PM2 ecosystem config file with .cjs extension' >> start.sh && \
    echo 'cat > ecosystem.config.cjs << EOF' >> start.sh && \
    echo 'module.exports = {' >> start.sh && \
    echo '  apps: [' >> start.sh && \
    echo '    {' >> start.sh && \
    echo '      name: "mcp-server",' >> start.sh && \
    echo '      cwd: "/app/rijksmuseum-mcp",' >> start.sh && \
    echo '      script: "build/index.js",' >> start.sh && \
    echo '      env: {' >> start.sh && \
    echo '        NODE_ENV: "production",' >> start.sh && \
    echo '        PORT: "\$MCP_PORT",' >> start.sh && \
    echo '        RIJKSMUSEUM_API_KEY: "\$RIJKSMUSEUM_API_KEY"' >> start.sh && \
    echo '      },' >> start.sh && \
    echo '      wait_ready: true,' >> start.sh && \
    echo '      listen_timeout: 10000' >> start.sh && \
    echo '    },' >> start.sh && \
    echo '    {' >> start.sh && \
    echo '      name: "web-interface",' >> start.sh && \
    echo '      cwd: "/app",' >> start.sh && \
    echo '      script: "server.js",' >> start.sh && \
    echo '      env: {' >> start.sh && \
    echo '        NODE_ENV: "production",' >> start.sh && \
    echo '        PORT: "\$PORT",' >> start.sh && \
    echo '        HOST: "\$HOST",' >> start.sh && \
    echo '        ANTHROPIC_API_KEY: "\$ANTHROPIC_API_KEY",' >> start.sh && \
    echo '        RIJKSMUSEUM_API_KEY: "\$RIJKSMUSEUM_API_KEY",' >> start.sh && \
    echo '        MCP_SERVER_URL: "\$MCP_SERVER_URL",' >> start.sh && \
    echo '        ALLOWED_ORIGINS: "\$ALLOWED_ORIGINS"' >> start.sh && \
    echo '      },' >> start.sh && \
    echo '      wait_ready: false,' >> start.sh && \
    echo '      depends_on: ["mcp-server"]' >> start.sh && \
    echo '    }' >> start.sh && \
    echo '  ]' >> start.sh && \
    echo '};' >> start.sh && \
    echo 'EOF' >> start.sh && \
    echo '' >> start.sh && \
    echo '# Start services with PM2' >> start.sh && \
    echo 'pm2-runtime start ecosystem.config.cjs' >> start.sh && \
    chmod +x start.sh

# Set environment variables with defaults
ENV PORT=3002
ENV MCP_PORT=3003
ENV HOST=0.0.0.0
ENV NODE_ENV=production
ENV MCP_SERVER_URL=http://localhost:3003

# Expose ports
EXPOSE 3002 3003

# Start services
CMD ["/app/start.sh"]
EOF

# Create docker-compose file
echo -e "${BLUE}Creating a fixed docker-compose file...${NC}"
cat > docker-compose.fix.yml << 'EOF'
version: '3'

services:
  rijksmuseum-combined:
    build:
      context: .
      dockerfile: Dockerfile.fix
    container_name: rijksmuseum-combined
    ports:
      - "${PORT:-3002}:${PORT:-3002}"
      - "${MCP_PORT:-3003}:${MCP_PORT:-3003}"
    environment:
      # These values will be overridden by your .env file
      - PORT=${PORT:-3002}
      - MCP_PORT=${MCP_PORT:-3003}
      - HOST=0.0.0.0
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - RIJKSMUSEUM_API_KEY=${RIJKSMUSEUM_API_KEY}
      - ALLOWED_ORIGINS=${ALLOWED_ORIGINS:-http://localhost:3002}
      - HOSTNAME=${HOSTNAME:-}
      # Using localhost for direct communication
      - MCP_SERVER_URL=http://localhost:${MCP_PORT:-3003}
    restart: unless-stopped
EOF

# Build and start the fixed container
echo -e "${BLUE}Building and starting the fixed container...${NC}"
docker-compose -f docker-compose.fix.yml down || true
docker-compose -f docker-compose.fix.yml build --no-cache
docker-compose -f docker-compose.fix.yml up -d

echo -e "${GREEN}Container rebuilt and launched with module compatibility fix${NC}"
echo -e "Check logs with: ${YELLOW}docker logs rijksmuseum-combined${NC}"
