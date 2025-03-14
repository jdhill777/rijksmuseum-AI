// Simple script to kill existing processes on port 3000 and restart server
import { exec } from 'child_process';

console.log('🔄 Restarting server...');

// Kill any processes running on port 3000
const killCommand = process.platform === 'win32' 
  ? 'for /f "tokens=5" %a in (\'netstat -ano ^| find ":3000" ^| find "LISTENING"\') do taskkill /f /pid %a'
  : 'lsof -ti:3000 | xargs kill -9';

exec(killCommand, (error, stdout, stderr) => {
  if (error) {
    console.log('No existing processes needed to be terminated.');
  } else {
    console.log('Terminated existing processes on port 3000');
  }
  
  console.log('Starting server...');
  exec('npm run dev', (error, stdout, stderr) => {
    if (error) {
      console.error('Error starting server:', error);
      return;
    }
    console.log(stdout);
  });
});
