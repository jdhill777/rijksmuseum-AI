# Rijksmuseum Art Explorer with Claude

This application allows you to explore artworks from the Rijksmuseum collection through natural language queries, powered by Claude AI.

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
3. Create a `.env` file with your API keys (copy from `.env.example`):
   ```
   ANTHROPIC_API_KEY=your-anthropic-key-here
   RIJKSMUSEUM_API_KEY=your-rijksmuseum-key-here
   PORT=3000
   ```
   - Get your Anthropic API key from: [https://console.anthropic.com/](https://console.anthropic.com/)
   - Get your Rijksmuseum API key from: [https://data.rijksmuseum.nl/object-metadata/api/](https://data.rijksmuseum.nl/object-metadata/api/)
4. Start the server:
   ```
   npm start
   ```
5. Access the application:
   - On the same computer: http://localhost:3000
   - From other devices (like mobile phones): http://YOUR_COMPUTER_IP:3000
     - Replace YOUR_COMPUTER_IP with your computer's IP address
     - Both devices must be on the same network

## Mobile Access Instructions

To access the application from a mobile device:

1. Make sure your computer and mobile device are connected to the same WiFi network
2. Find your computer's IP address:
   - On macOS: Run `ipconfig getifaddr en0` in Terminal
   - On Windows: Run `ipconfig` in Command Prompt and look for IPv4 Address
   - On Linux: Run `hostname -I` in Terminal
3. On your mobile device, open a browser and enter: http://YOUR_COMPUTER_IP:3000
4. If you have trouble connecting, check your computer's firewall settings to ensure it allows connections on port 3000

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

## Troubleshooting

If you encounter connectivity issues:

1. **Firewall Settings**: Ensure your firewall allows incoming connections on port 3000
2. **Network Issues**: Verify both devices are on the same network
3. **Server Logs**: Check the terminal where the server is running for error messages
4. **Restart Server**: Try stopping and restarting the server

## Technologies Used

- Frontend: HTML, CSS, JavaScript
- Backend: Node.js, Express
- APIs: Rijksmuseum API, Anthropic Claude AI
- Utilities: Translation, CORS support
