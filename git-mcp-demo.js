#!/usr/bin/env node
/**
 * Git MCP Server Demonstration Script
 * 
 * This script demonstrates how to use the Git MCP server tools.
 * 
 * To run this script:
 * 1. Make sure you've installed the Git MCP server in your Claude Desktop and/or Cline extension settings
 * 2. Run: node git-mcp-demo.js
 */

console.log('Git MCP Server Demonstration\n');
console.log('The Git MCP server has been installed with the following configuration:');
console.log(`
In claude_desktop_config.json:
{
  "mcpServers": {
    "github.com/modelcontextprotocol/servers/tree/main/src/git": {
      "command": "uvx",
      "args": ["mcp-server-git", "--repository", "/Users/jackhill/Desktop/rijksmuseum-interface"],
      "disabled": false,
      "autoApprove": []
    }
  }
}
`);

console.log('\nOnce the Git MCP server is properly connected, you can use the following tools:');
console.log('\n1. git_status - Shows the working tree status');
console.log('   Example: use_mcp_tool with git_status and repo_path parameter');

console.log('\n2. git_diff_unstaged - Shows changes in working directory not yet staged');
console.log('   Example: use_mcp_tool with git_diff_unstaged and repo_path parameter');

console.log('\n3. git_diff_staged - Shows changes that are staged for commit');
console.log('   Example: use_mcp_tool with git_diff_staged and repo_path parameter');

console.log('\n4. git_diff - Shows differences between branches or commits');
console.log('   Example: use_mcp_tool with git_diff, repo_path and target parameters');

console.log('\n5. git_commit - Records changes to the repository');
console.log('   Example: use_mcp_tool with git_commit, repo_path and message parameters');

console.log('\n6. git_add - Adds file contents to the staging area');
console.log('   Example: use_mcp_tool with git_add, repo_path and files parameters');

console.log('\n7. git_reset - Unstages all staged changes');
console.log('   Example: use_mcp_tool with git_reset and repo_path parameter');

console.log('\n8. git_log - Shows the commit logs');
console.log('   Example: use_mcp_tool with git_log, repo_path and max_count parameters');

console.log('\n9. git_create_branch - Creates a new branch');
console.log('   Example: use_mcp_tool with git_create_branch, repo_path and branch_name parameters');

console.log('\n10. git_checkout - Switches branches');
console.log('   Example: use_mcp_tool with git_checkout, repo_path and branch_name parameters');

console.log('\n11. git_show - Shows the contents of a commit');
console.log('   Example: use_mcp_tool with git_show, repo_path and revision parameters');

console.log('\n12. git_init - Initializes a Git repository');
console.log('   Example: use_mcp_tool with git_init and repo_path parameter');

console.log('\nTroubleshooting:');
console.log('1. Make sure the Git MCP server is properly configured in your settings');
console.log('2. Try restarting VSCode or the Claude Desktop app');
console.log('3. Check if uvx is properly installed and in your PATH');
console.log('4. Look at the logs: tail -n 20 -f ~/Library/Logs/Claude/mcp*.log');

// Show what the current repository looks like with regular git commands
const { execSync } = require('child_process');
try {
  console.log('\nCurrent repository status (using regular git command):');
  const status = execSync('git status', { encoding: 'utf8' });
  console.log(status);
  
  console.log('Recent commits (using regular git command):');
  const log = execSync('git log --oneline -n 3', { encoding: 'utf8' });
  console.log(log);
} catch (error) {
  console.error('Error executing git commands:', error.message);
}
