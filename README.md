# Rijksmuseum Art Explorer with Claude

This application allows you to explore artworks from the Rijksmuseum collection through natural language queries, powered by Claude AI.

## Architecture

This is a standalone web application with:

- **Backend**: Node.js/Express server that communicates directly with external APIs
- **Frontend**: Simple HTML/CSS/JavaScript interface

The application uses a direct integration architecture:
1. Your Express server makes API calls to Rijksmuseum's API using your API key
2. Your server also makes direct API calls to Anthropic's Claude API
3. The frontend communicates only with your Express server, not directly with external APIs

This design keeps API keys secure on the server side and simplifies the frontend implementation.

## Features

- **Natural Language Search**: Ask about artworks in plain English
- **Dark Mode by Default**: Elegant dark theme with light theme toggle
- **Responsive Design**: Works on both desktop and mobile devices
- **Artwork Details**: View comprehensive information about each artwork
- **Fullscreen Viewing**: Click on artwork images to view them in fullscreen mode
- **No Image Placeholders**: Graceful handling of artworks without images
- **Automatic Translation**: Dutch text is automatically translated to English

## Running the Application

1. Ensure you have Node.js installed
2. Install dependencies:
   ```
   npm install
   ```
3. Create a `.env` file with your API keys:
   - **Option 1**: Rename the `.env.example` file to `.env` 
   - **Option 2**: Copy the contents from `.env.example` to a new `.env` file
   
   Then fill in your API keys and configure as needed:
   ```
   ANTHROPIC_API_KEY=your-anthropic-key-here
   RIJKSMUSEUM_API_KEY=your-rijksmuseum-key-here
   PORT=3000                  # You can change this to any port number you prefer!
   HOST=0.0.0.0
   ALLOWED_ORIGINS=
   HOSTNAME=
   ```

   **⚠️ SECURITY WARNING**:
   - Never commit your `.env` file to version control
   - Regularly rotate your API keys, especially if they might have been exposed
   - Use different API keys for development and production
   - Consider using environment variables in production deployments instead of `.env` files
   - Get your Anthropic API key from: [https://console.anthropic.com/](https://console.anthropic.com/)
   - Get your Rijksmuseum API key from: [https://data.rijksmuseum.nl/object-metadata/api/](https://data.rijksmuseum.nl/object-metadata/api/)
4. Configure server options in the `.env` file:
   - `PORT`: ⚡ **Pick any port number you want!** (default is 3000)
     - This is the "door number" your app will use on your computer
     - If 3000 is already in use, try 3001, 8080, or any other number
   - `HOST`: The network access setting
     - Use `0.0.0.0` to allow access from other devices like phones or tablets
     - Use `127.0.0.1` or `localhost` for private access (your computer only)
   - `ALLOWED_ORIGINS`: Which websites can access your app (important for security)
     - For personal use on your own computer, you can leave this empty
     - If hosting online, include your domain: `http://localhost:YOUR_PORT,https://your-domain.com`
   - `HOSTNAME`: (Optional - only needed if hosting with a custom domain)
     - Most users can leave this blank
     - Example: `art.example.com` or your domain name

5. Start the server:
   ```
   npm start
   ```
6. Access the application:
   - On the same computer: http://localhost:YOUR_PORT
     - Replace YOUR_PORT with the port number you chose in the `.env` file (e.g., http://localhost:3000)
   - From other devices (like mobile phones or tablets): http://YOUR_COMPUTER_IP:YOUR_PORT
     - Replace YOUR_COMPUTER_IP with your computer's IP address
     - Replace YOUR_PORT with your chosen port number
     - Both devices must be connected to the same WiFi network

## Mobile Access Instructions

To access the application from a mobile device:

1. Make sure your computer and mobile device are connected to the same WiFi network
2. Find your computer's IP address:
   - On macOS: Run `ipconfig getifaddr en0` in Terminal
   - On Windows: Run `ipconfig` in Command Prompt and look for IPv4 Address
   - On Linux: Run `hostname -I` in Terminal
3. On your mobile device, open a browser and enter: http://YOUR_COMPUTER_IP:YOUR_PORT
   - Replace YOUR_COMPUTER_IP with the IP address you found
   - Replace YOUR_PORT with the port number you chose in your `.env` file
4. If you have trouble connecting, check your computer's firewall settings to ensure it allows connections on your chosen port

## Example Queries

Try asking about artworks in various ways:

### Artwork Discovery
- "Show me paintings by Rembrandt from the 1640s"
- "Find artworks that prominently feature the color blue"
- "What are the most famous masterpieces in the collection?"
- "Search for still life paintings from the Dutch Golden Age"

### Artwork Analysis
- "Tell me everything about The Night Watch"
- "What are the dimensions of Van Gogh's Self Portrait?"
- "Show me details of Vermeer's The Milkmaid"

### Artist Research
- "Show me all works by Frans Hals"
- "How did Van Gogh's style evolve?"

### Thematic Exploration
- "Find all artworks depicting biblical scenes"
- "Show me paintings of Amsterdam in the 17th century"
- "What artworks feature flowers or still life arrangements?"
- "Find portraits that include musical instruments"

## Configuration Examples

### Basic Setup (Most Users)
```
PORT=8080                        # Any port number you prefer!
HOST=0.0.0.0                     # Allow access from other devices on your network
ALLOWED_ORIGINS=http://localhost:8080  # Match your chosen port number here
HOSTNAME=                        # Leave empty (you don't need this)
```

### Advanced: Hosting Online
```
PORT=9000                        # Any port number you prefer!
HOST=0.0.0.0                     # Allow access from any device
ALLOWED_ORIGINS=http://localhost:9000,https://your-domain.com
HOSTNAME=your-domain.com         # Your domain name if hosting online
```

## Troubleshooting

If you encounter connectivity issues:

1. **Wrong Port Number**: Make sure you're using the same port number in:
   - Your `.env` file (the PORT setting)
   - Your browser URL (the number after the colon)
   - Your ALLOWED_ORIGINS setting

2. **Port Already in Use**: If you see an error like "port already in use":
   - Try a different port number in your `.env` file
   - Common alternatives: 8080, 5000, 3001, 4000

3. **Can't Connect from Phone/Tablet**: 
   - Make sure HOST is set to `0.0.0.0` in your `.env` file
   - Ensure both devices are on the same WiFi network
   - Check that your firewall allows connections on your chosen port

4. **App Not Working Correctly**:
   - Make sure your API keys are correctly entered in the `.env` file
   - Check the terminal for any error messages
   - Try stopping the server (press Ctrl+C in the terminal) and restarting it

5. **Domain Configuration**: If hosting with a custom domain, make sure your HOSTNAME is set correctly

## Technologies Used

- Frontend: HTML, CSS, JavaScript
- Backend: Node.js, Express
- APIs: Rijksmuseum API, Anthropic Claude AI
- Utilities: Translation, CORS support

## Docker Installation

You can run this application in a Docker container, which is especially useful for running on Unraid or other server platforms.

### Prerequisites

- Docker and Docker Compose installed on your system
- For Unraid: Docker support enabled in Unraid settings

### Option 1: Using Docker Compose (Recommended)

1. Make sure your `.env` file is set up correctly with your API keys and configuration
2. Build and start the container:
   ```bash
   docker-compose up -d
   ```
3. Access the application at http://YOUR_SERVER_IP:3000 (or your configured port)
4. To stop the container:
   ```bash
   docker-compose down
   ```

### Option 2: Using Docker Directly

1. Build the Docker image:
   ```bash
   docker build -t rijksmuseum-interface .
   ```
2. Run the container:
   ```bash
   docker run -d \
     -p 3000:3000 \
     -e ANTHROPIC_API_KEY=your_api_key \
     -e RIJKSMUSEUM_API_KEY=your_api_key \
     -e PORT=3000 \
     -e HOST=0.0.0.0 \
     -e ALLOWED_ORIGINS=http://your-server-ip:3000 \
     --name rijksmuseum-interface \
     rijksmuseum-interface
   ```
   
### Running on Unraid

1. On your Unraid server, go to the Docker tab
2. Click "Add Container"
3. Use one of these methods:
   
   **Method A: Use a pre-built image** (if you've pushed to Docker Hub)
   - Repository: `yourusername/rijksmuseum-interface`
   - Port Mappings: Host `3000`, Container `3000`
   
   **Method B: Build from local files**
   - Navigate to where you've saved the project files on your Unraid server
   - Run the docker-compose command as shown in Option 1
   
4. Add Environment Variables:
   - ANTHROPIC_API_KEY=your_api_key
   - RIJKSMUSEUM_API_KEY=your_api_key
   - (others as needed)
   
5. Click "Apply" to create and start the container

### Environment Variables

The Docker container uses the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| ANTHROPIC_API_KEY | Your Anthropic API key | None (Required) |
| RIJKSMUSEUM_API_KEY | Your Rijksmuseum API key | None (Required) |
| PORT | The port the app runs on | 3000 |
| HOST | Host to bind to | 0.0.0.0 |
| ALLOWED_ORIGINS | CORS allowed origins | http://localhost:3000 |
| HOSTNAME | Custom domain name if used | None |

## Security Considerations

1. **API Key Management**:
   - The `.env` file is excluded from version control in `.gitignore`
   - If you believe your API keys have been exposed, rotate them immediately:
     - Anthropic: [https://console.anthropic.com/keys](https://console.anthropic.com/keys)
     - Rijksmuseum: [https://data.rijksmuseum.nl/object-metadata/api/](https://data.rijksmuseum.nl/object-metadata/api/)
   - When using Docker, prefer to use environment variables or Docker secrets instead of mounting the .env file

2. **CORS Configuration**:
   - The `ALLOWED_ORIGINS` setting restricts which domains can access your API
   - In production, explicitly list all allowed origins rather than using wildcards

3. **Local Network Exposure**:
   - When running on `0.0.0.0`, the server is accessible to all devices on your network
   - For increased security in development, use `127.0.0.1` to restrict access to your computer only
   - On Unraid, consider using Unraid's built-in reverse proxy or configuring a firewall
