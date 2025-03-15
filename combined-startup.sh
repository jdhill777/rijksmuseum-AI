#!/bin/sh
# Combined startup script for Rijksmuseum web app and MCP server

# Print environment for debugging
echo "Starting Rijksmuseum services with the following configuration:"
echo "Web server port: $PORT"
echo "MCP server port: $MCP_PORT"
echo "MCP server URL: $MCP_SERVER_URL"

# Create PM2 ecosystem config file dynamically
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [
    {
      name: 'mcp-server',
      cwd: '/app/rijksmuseum-mcp',
      script: 'build/index.js',
      env: {
        NODE_ENV: 'production',
        PORT: '$MCP_PORT',
        RIJKSMUSEUM_API_KEY: '$RIJKSMUSEUM_API_KEY'
      },
      wait_ready: true,
      listen_timeout: 10000
    },
    {
      name: 'web-interface',
      cwd: '/app',
      script: 'server.js',
      env: {
        NODE_ENV: 'production',
        PORT: '$PORT',
        HOST: '$HOST',
        ANTHROPIC_API_KEY: '$ANTHROPIC_API_KEY',
        RIJKSMUSEUM_API_KEY: '$RIJKSMUSEUM_API_KEY',
        MCP_SERVER_URL: '$MCP_SERVER_URL',
        ALLOWED_ORIGINS: '$ALLOWED_ORIGINS'
      },
      wait_ready: false,
      depends_on: ['mcp-server']
    }
  ]
};
EOF

# Start services with PM2
echo "Starting services with PM2..."
pm2-runtime start ecosystem.config.js
