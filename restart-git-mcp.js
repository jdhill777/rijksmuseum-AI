#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// Path to the Claude Desktop config file
const claudeConfigPath = path.join(process.env.HOME, 'Library/Application Support/Claude/claude_desktop_config.json');

console.log('Stopping Claude Desktop application...');
// Find and kill any running Claude process
const killProcess = spawn('pkill', ['-x', 'Claude']);

killProcess.on('close', (code) => {
  console.log('Claude process killed with code:', code);
  
  // Wait a moment before restarting
  setTimeout(() => {
    console.log('Restarting MCP server...');
    
    // Open Claude application
    const openProcess = spawn('open', ['-a', 'Claude']);
    
    openProcess.on('close', (code) => {
      console.log('Claude application restarted with code:', code);
      console.log('MCP git server should now be available.');
      console.log('Try using the git_status MCP tool on this repository.');
    });
    
    openProcess.stderr.on('data', (data) => {
      console.error('Error restarting Claude:', data.toString());
    });
  }, 2000);
});

killProcess.stderr.on('data', (data) => {
  console.error('Error killing Claude process:', data.toString());
});

// Add a dummy file to the git repository for status checking
fs.writeFileSync(
  path.join(process.cwd(), 'test-git-file.txt'), 
  'This is a test file for the Git MCP server demo.\n' +
  'Created at: ' + new Date().toISOString() + '\n'
);

console.log('Created test-git-file.txt for git status demonstration');
