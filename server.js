import express from 'express';
import cors from 'cors';
import { exec } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import bodyParser from 'body-parser';
import fetch from 'node-fetch';
import Anthropic from '@anthropic-ai/sdk';
import dotenv from 'dotenv';
import translate from 'translate';

// Load environment variables
dotenv.config();

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Parse HOST value, removing any comments
const parseHost = (hostStr) => {
  if (!hostStr) return '0.0.0.0'; // Default to all network interfaces
  // Split on space or # and take the first part
  return hostStr.split(/[\s#]/)[0].trim();
};
const HOST = parseHost(process.env.HOST);
console.log(`Using host: ${HOST}`);

// Get current directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Extract allowed origins from environment or use defaults
const allowedOriginsEnv = process.env.ALLOWED_ORIGINS || '';
const allowedOrigins = allowedOriginsEnv
  ? allowedOriginsEnv.split(',')
  : ['http://localhost:' + PORT, '*'];

// Middleware - Enhanced CORS for external access
app.use(cors({
  origin: allowedOrigins,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));
app.use(bodyParser.json());

// Add a Cloudflare-specific debug endpoint
app.get('/debug-info', (req, res) => {
  res.json({
    headers: req.headers,
    url: req.url,
    method: req.method,
    ip: req.ip,
    serverTime: new Date().toISOString(),
    env: {
      NODE_ENV: process.env.NODE_ENV || 'development'
    }
  });
});

// Serve static files with aggressive cache control headers for Cloudflare
app.use(express.static(__dirname, {
  setHeaders: (res, path) => {
    // Add cache-busting headers for ALL files to prevent Cloudflare caching
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    
    // Add Cloudflare-specific headers
    res.setHeader('CF-Cache-Status', 'BYPASS');
    
    // Add custom header to track file version
    res.setHeader('X-File-Version', Date.now().toString());
    
    // Special handling for CSS and JS to make animations work
    if (path.endsWith('.css') || path.endsWith('.js')) {
      res.setHeader('Content-Type', path.endsWith('.css') ? 'text/css; charset=utf-8' : 'application/javascript; charset=utf-8');
    }
  }
}));

// Response modifier middleware - ensure all responses have proper headers
app.use((req, res, next) => {
  // Store the original send method
  const originalSend = res.send;
  
  // Override the send method
  res.send = function(body) {
    // Add no-cache headers to all responses
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    
    // Continue with the original send
    return originalSend.call(this, body);
  };
  
  next();
});

// Add specific CORS headers for all responses
app.use((req, res, next) => {
  const origin = req.headers.origin;
  
  if (origin && allowedOrigins.includes(origin)) {
    res.header('Access-Control-Allow-Origin', origin);
  } else {
    res.header('Access-Control-Allow-Origin', '*');
  }
  
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Credentials', 'true');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  next();
});

// Rijksmuseum API key from environment variables
const RIJKSMUSEUM_API_KEY = process.env.RIJKSMUSEUM_API_KEY;

// Helper function to communicate with Rijksmuseum API
async function searchArtworks(query, options = {}) {
  // Create URL search parameters with all needed options
  const params = new URLSearchParams({
    key: RIJKSMUSEUM_API_KEY,
    q: query,
    return: 'json',
    imgonly: true,
    toppieces: true,
    ps: options.limit || 15,
    s: 'relevance', // Sort by relevance
    p: options.page || 1, // Add page parameter with default of 1
    language: 'en',
    f: [
      'plaqueDescriptionEnglish',
      'description',
      'label',
      'title',
      'scLabelLine',
      'physicalMedium',
      'materials',
      'techniques',
      'subTitle',
      'dimensions',
      'dimensionParts',
      'location',
      'currentLocation',
      'gallery'
    ].join(',')
  });
  
  // Add any additional options as query parameters
  if (options) {
    Object.keys(options).forEach(key => {
      if (!['limit', 'page'].includes(key) && !params.has(key)) {
        params.append(key, options[key]);
      }
    });
  }
  
  // Log request details for debugging
  console.log('Searching Rijksmuseum API with params:', {
    url: `https://www.rijksmuseum.nl/api/en/collection?${params}`,
    query: query,
    page: options.page || 1
  });

  try {
    const response = await fetch(`https://www.rijksmuseum.nl/api/en/collection?${params}`);
    
    if (!response.ok) {
      throw new Error(`Rijksmuseum API error: ${response.status}`);
    }
    
    const data = await response.json();
    return data.artObjects || [];
  } catch (error) {
    console.error('Error fetching from Rijksmuseum API:', error);
    return [];
  }
}

// Helper function to get artwork details
async function getArtworkDetails(objectNumber) {
  try {
    // Get the artwork details with specific fields we need
    const params = new URLSearchParams({
      key: RIJKSMUSEUM_API_KEY,
      return: 'json',
      language: 'en',
      format: 'json',
      p: [
        'plaqueDescriptionEnglish',
        'description',
        'label',
        'title',
        'scLabelLine',
        'physicalMedium',
        'materials',
        'techniques',
        'subTitle',
        'dimensions',
        'dimensionParts',
        'location',
        'currentLocation',
        'gallery'
      ].join(',')
    });

    console.log('Fetching artwork details with params:', params.toString());
    const response = await fetch(
      `https://www.rijksmuseum.nl/api/en/collection/${objectNumber}?${params}`
    );
    
    if (!response.ok) {
      throw new Error(`Rijksmuseum API error: ${response.status}`);
    }
    
    const data = await response.json();
    
    // Log the raw API response for debugging
    console.log('API Response:', {
      plaqueDescriptionEnglish: data.artObject?.plaqueDescriptionEnglish,
      physicalMedium: data.artObject?.physicalMedium,
      dimensions: data.artObject?.dimensions,
      location: data.artObject?.location,
      subTitle: data.artObject?.subTitle,
      materials: data.artObject?.materials,
      techniques: data.artObject?.techniques,
      scLabelLine: data.artObject?.scLabelLine,
      title: data.artObject?.title
    });
    
    // Structure the response with the fields we need
    const processedData = {
      artObject: {
        ...data.artObject,
        // Description: prioritize plaque description, then label, then title
        plaqueDescriptionEnglish: data.artObject?.plaqueDescriptionEnglish || 
                                 data.artObject?.label?.description ||
                                 data.artObject?.scLabelLine || 
                                 data.artObject?.description ||
                                 data.artObject?.title || '',
        
        // Physical Medium: combine medium, materials, and techniques
        physicalMedium: [
          data.artObject?.physicalMedium,
          data.artObject?.materials?.length ? data.artObject.materials.join(', ') : null,
          data.artObject?.techniques?.length ? data.artObject.techniques.join(', ') : null
        ].filter(Boolean).join(' - ') || 'Information not available',
        
        // Dimensions: use subTitle or detailed dimensions
        dimensions: data.artObject?.dimensionParts || data.artObject?.dimensions || [],
        subTitle: data.artObject?.subTitle || '',
        
        // Location: try all possible location fields
        location: data.artObject?.location || 
                 data.artObject?.currentLocation || 
                 data.artObject?.gallery || 
                 'Information not available'
      }
    };


    // Log the final processed data structure
    console.log('Final processed data:', {
      plaqueDescriptionEnglish: processedData.artObject.plaqueDescriptionEnglish?.substring(0, 100) + '...',
      physicalMedium: processedData.artObject.physicalMedium,
      dimensions: processedData.artObject.dimensions,
      location: processedData.artObject.location,
      subTitle: processedData.artObject.subTitle
    });
    
    return processedData;
  } catch (error) {
    console.error('Error fetching artwork details:', error);
    throw error;
  }
}

// Initialize Anthropic client with required API key
// Make sure to set your API key in .env file
console.log('Using Anthropic API key starting with:', 
  process.env.ANTHROPIC_API_KEY ? 
  `${process.env.ANTHROPIC_API_KEY.substring(0, 12)}...` : 
  'NO API KEY FOUND');

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY || 'your-anthropic-api-key',
});

// API endpoint for chat
app.post('/api/chat', async (req, res) => {
  console.log('Received chat request:', req.body);
  
  const { message, page = 1 } = req.body;
  
  if (!message) {
    console.log('No message provided in request');
    return res.status(400).json({ error: 'No message provided' });
  }
  
    try {
      console.log('Processing request for message:', message);
      let claudeResponse = null;
      let searchTerms = message;
      
      // Prepare response object
      const responseObject = {
        artworks: [],
        relevanceTags: []
      };
      
      try {
        console.log('Attempting to call Claude API...');
        // Always attempt to use Claude with the server's API key
        claudeResponse = await anthropic.messages.create({
          model: 'claude-3-opus-20240229',
          max_tokens: 1000,
          system: `You are an art expert specializing in the Rijksmuseum collection. 
            Help users discover and learn about artwork from the museum. 
            When users ask to see specific types of artwork, analyze their query to extract key search terms, such as:
            - Artist names
            - Time periods
            - Art styles
            - Subject matter
            - Colors
            - Materials
            
            Keep your responses concise and informative. Focus on providing interesting context about the artwork that will be displayed.`,
          messages: [
            {
              role: 'user',
              content: message
            }
          ]
        });
        console.log('Successfully received Claude response');
        
          // Extract search terms and relevance tags
          try {
            const termExtractor = await anthropic.messages.create({
              model: 'claude-3-haiku-20240307',
              max_tokens: 400, // Increased for more detailed response
              system: `You are an elite art historian with encyclopedic knowledge of the Rijksmuseum collection and Dutch art. Your task is to translate user queries into optimal search terms for the Rijksmuseum API.

CRITICAL OBJECTIVES:
- Identify the true user intent behind queries about artworks
- Convert common language into specialized art-historical terminology
- Ensure search terms yield relevant, historically accurate results
- For simple artist-specific queries, preserve the artist's name and intent
- NEVER include modern objects, social messaging, or contemporary content in historical searches
- Handle time periods explicitly for date-specific searches

DETAILED KNOWLEDGE BASE:

1. ART PERIODS AND CORRESPONDING MASTERS:
   - Dutch Golden Age (1588-1672): Rembrandt (active 1625-1669), Vermeer (active 1653-1675), Frans Hals (active 1610-1666)
   - Rembrandt's Decades: 1630s (early portraits), 1640s (biblical narratives, Night Watch), 1650s-1660s (introspective works)
   - Renaissance (1400-1600): Hieronymus Bosch, Lucas van Leyden
   - Baroque (1600-1750): Rubens, Van Dyck
   - Romanticism (1800-1850): Théodore Géricault
   - Modern/Post-Impressionism (1880-1920): Van Gogh, Breitner, Mondrian

2. GENRES AND SPECIALIZED ARTISTS:
   - Still Life: Willem Kalf (luxury objects), Willem Claesz Heda (banquet pieces), Pieter Claesz (vanitas), Jan Davidsz de Heem (flowers)
   - Landscape: Jacob van Ruisdael (dramatic scenes), Meindert Hobbema (wooded landscapes), Jan van Goyen (atmospheric scenes)
   - Portrait: Rembrandt (psychological depth), Frans Hals (vivid expressions), Johannes Verspronck (elegant poses)
   - Genre Scenes: Jan Steen (chaotic households), Pieter de Hooch (domestic scenes), Vermeer (quiet interiors)
   - History Painting: Rembrandt (biblical scenes), Ferdinand Bol (mythological subjects)
   - Marine: Willem van de Velde (naval battles), Ludolf Backhuysen (stormy seas)

3. SUBJECT MATTER SPECIFICS:
   - Religious: "biblical scene" "passion of christ" "old testament" "new testament"
   - Mythological: "greek myth" "roman gods" "metamorphoses" "ovid"
   - Daily Life: "tavern scene" "domestic interior" "merrymaking" "peasant"
   - Trade/Economy: "merchant" "east india company" "trade goods" "commerce"
   - Landscape Features: "windmill" "dutch countryside" "winter scene" "frozen canal"

4. ARTISTIC TECHNIQUES:
   - Painting Effects: "chiaroscuro" "impasto" "glazing" "sfumato" 
   - Color Palettes: "monochrome" "earthy palette" "jewel tones" "Utrecht caravaggisti"
   - Compositional Terms: "vanishing point" "rule of thirds" "repoussoir" "trompe l'oeil"

5. RIJKSMUSEUM COLLECTION STRENGTHS:
   - Masterpieces: "Night Watch" "Milkmaid" "The Threatened Swan" "The Merry Family"
   - Strong Collections: Dutch masters, Asian art, Delftware, weapons/armor, doll houses
   - Limitations: Less extensive in non-Dutch art, modern art (prefer Stedelijk Museum)

6. SEARCH OPTIMIZATION STRATEGIES:
   - SIMPLE ARTIST QUERIES: For simple queries like "paintings by Van Gogh", just use "Van Gogh" as the search term
   - Always include artist surnames when known or applicable to the period/genre
   - Add relevant material terms: "oil painting" "canvas" "panel" "watercolor" "etching"
   - For any period search, include 2-3 most significant artists from that period
   - For genre searches, include both genre name AND likely subjects (e.g. "still life fruit flowers")
   - Avoid overly broad terms like "art" or "painting" that dilute search effectiveness
   - When period and genre are specified, prioritize genre-specific masters from that period

7. CULTURAL/HISTORICAL CONTEXT:
   - Protestant Reformation impact: reduced religious imagery, increased secular subjects
   - Dutch colonial expansion: emergence of exotic subjects, Asian influences
   - Dutch Republic's merchant class: rise of portrait commissions, domestic scenes
   - Counter-Reformation: Catholic symbolic imagery, allegorical content

8. CONTEMPORARY EXCLUSIONS:
   - NEVER return modern signage, informational graphics, or museum installations
   - NEVER return digital art, photographs, or post-1950 works for historical queries
   - Add term "historical" for any pre-20th century query to enforce temporal relevance
   - For queries with specific time periods (like "1640s", "17th century", etc.), add negative terms to exclude modern content: "-modern -COVID -social -distancing -meter -meters -guidance"
   - When handling decade-specific searches like "1640s", translate to explicit year range: "1640-1649"

YOU MUST ONLY RETURN VALID JSON. DO NOT include any explanation, markdown formatting, or text outside the JSON.
Return a JSON object with exactly these properties:
{
  "searchTerms": "extracted main search terms optimized for API",
  "relevanceTags": ["tag1", "tag2", "tag3"]
}

Example conversions:
"Show me still life paintings" → {"searchTerms":"still life painting Heda Claesz fruit flowers banquet","relevanceTags":["Still life","Dutch Golden Age","Willem Claesz Heda"]}

"I want to see landscapes with windmills" → {"searchTerms":"landscape windmill Ruisdael Hobbema Dutch countryside historical","relevanceTags":["Dutch landscape","Windmills","Jacob van Ruisdael"]}

"Find portraits by Rembrandt" → {"searchTerms":"Rembrandt portrait","relevanceTags":["Rembrandt van Rijn","Portrait","Dutch Golden Age"]}

"Show me paintings by Van Gogh" → {"searchTerms":"Van Gogh","relevanceTags":["Vincent van Gogh","Post-Impressionism","Dutch artist"]}

"Show me artwork of Amsterdam canals" → {"searchTerms":"Amsterdam canal view Berckheyde water boats historical","relevanceTags":["Amsterdam","Dutch cityscape","Gerrit Berckheyde"]}`,
            messages: [
              {
                role: 'user',
                content: message
              }
            ]
          });
          
          // Try to extract just the JSON part from the response if it contains non-JSON text
          let jsonText = termExtractor.content[0].text.trim();
          
          // Find where JSON object starts and ends if there's any surrounding text
          const jsonStartIndex = jsonText.indexOf('{');
          const jsonEndIndex = jsonText.lastIndexOf('}');
          
          if (jsonStartIndex >= 0 && jsonEndIndex > jsonStartIndex) {
            jsonText = jsonText.substring(jsonStartIndex, jsonEndIndex + 1);
          }
          
          // Parse the JSON text
          const extractedData = JSON.parse(jsonText);
          // Use more specific search terms if available, otherwise fall back to original message
          if (extractedData.searchTerms && extractedData.searchTerms.trim()) {
            console.log(`Using extracted search terms: "${extractedData.searchTerms}"`);
            searchTerms = extractedData.searchTerms;
          } else {
            console.log(`No valid search terms extracted, using original message`);
            searchTerms = message;
          }
          
          // Use extracted relevance tags if available
          if (Array.isArray(extractedData.relevanceTags) && extractedData.relevanceTags.length > 0) {
            responseObject.relevanceTags = extractedData.relevanceTags;
          } else {
            responseObject.relevanceTags = [message];
          }
        } catch (extractError) {
          console.error('Error extracting search terms:', extractError);
          console.log('Falling back to using the artist name or key terms from the message');
          
          // Extract artist name if it contains "by [Artist Name]"
          const artistMatch = message.match(/\b(?:by|from)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i);
          if (artistMatch && artistMatch[1]) {
            searchTerms = artistMatch[1] + " " + message.split(artistMatch[0])[0].trim();
          } else {
            searchTerms = message;
          }
          
          responseObject.relevanceTags = [message];
        }
      } catch (claudeError) {
        console.error('Error getting Claude response:', claudeError);
        // Provide a fallback response even if Claude fails
        claudeResponse = { content: [{ text: `Here are some artworks related to "${message}" from the Rijksmuseum collection.` }] };
      }
      
      // Preprocess search terms for time period queries
      const decadeMatch = message.match(/\b(\d{4})s\b/i); // Match patterns like "1640s"
      const timeQuery = decadeMatch || 
                     message.toLowerCase().includes('century') ||
                     message.match(/\b(\d{4})-(\d{4})\b/); // Match year ranges
      
      // Apply special processing for time periods to avoid modern signage
      if (timeQuery) {
        console.log('Detected time period query, applying special processing');
        
        // Handle specific decade queries (e.g., "1640s")
        if (decadeMatch) {
          const decade = decadeMatch[1];
          const yearStart = decade;
          const yearEnd = parseInt(decade) + 9;
          
          if (message.toLowerCase().includes('rembrandt')) {
            console.log(`Detected Rembrandt ${decade}s query, using optimized search terms`);
            searchTerms = `Rembrandt ${yearStart}-${yearEnd} painting -modern -signage -COVID -social -distancing -meter -meters`;
          } else {
            // Add time range and exclusion terms to the search
            searchTerms = `${searchTerms} ${yearStart}-${yearEnd} -modern -signage -COVID -distancing`;
          }
        } else {
          // For other time period queries, just add exclusion terms
          searchTerms = `${searchTerms} -modern -signage -COVID -social -distancing -meter -meters`;
        }
      }
      
      // Search for artworks with pagination support
      console.log(`Searching Rijksmuseum API for: "${searchTerms}" (page ${page})`);
      
      // Create pagination parameters
      const pageNum = parseInt(page) || 1;
      
      // Fetch results with proper pagination parameters
      const artworks = await searchArtworks(searchTerms, { 
        p: pageNum  // This is the actual Rijksmuseum API parameter for page
      });
      
      // Get the total number of results from API by doing a count-only request
      const countResponse = await searchArtworks(searchTerms, { 
        p: 0, 
        ps: 1,  // Only get 1 result for counting
        imgonly: true
      });
      
      // Determine if there are more results beyond this page
      const resultsPerPage = 15; // Number of results per page
      const pageStart = (pageNum - 1) * resultsPerPage + 1;
      const pageEnd = pageStart + artworks.length - 1;
      
      console.log(`Found ${artworks.length} artworks for search term: "${searchTerms}" (page ${page}, items ${pageStart}-${pageEnd})`);
      
      // Update response object with artworks
      responseObject.artworks = artworks;
    
    console.log('Preparing response with:', artworks.length, 'artworks');
    
    // Calculate if there are likely more results available
    // We need to set this explicitly to true for Van Gogh searches which may not
    // return exactly 15 per page but still have more pages
    const isVanGoghSearch = searchTerms.toLowerCase().includes('van gogh') || 
                          searchTerms.toLowerCase().includes('vangogh') ||
                          searchTerms.toLowerCase().includes('gogh');
                          
    // Set hasMoreResults to true if:
    // 1. We have a full page of results (15 items)
    // 2. OR it's a Van Gogh search with at least 5 results
    // 3. OR we're on page 1 with at least 10 results (indicating likely more available)
    responseObject.hasMoreResults = artworks.length >= 15 || 
                                  (isVanGoghSearch && artworks.length >= 5) ||
                                  (pageNum === 1 && artworks.length >= 10);
                                  
    console.log('Setting hasMoreResults:', responseObject.hasMoreResults, 
                'Full page:', artworks.length >= 15,
                'Van Gogh search:', isVanGoghSearch,
                'Page 1 with 10+ results:', (pageNum === 1 && artworks.length >= 10));
    
    // Special handling if no artworks were found
    if (artworks.length === 0 && page === 1) {
      // Check if query might be for sensitive content
      const sensitiveTerms = ['nude', 'nudity', 'naked', 'sex', 'erotic', 'explicit', 'adult'];
      const isSensitiveQuery = sensitiveTerms.some(term => 
        searchTerms.toLowerCase().includes(term) || message.toLowerCase().includes(term)
      );
      
      if (isSensitiveQuery) {
        responseObject.response = `I couldn't find any artworks matching your search for sensitive content. The Rijksmuseum API has certain limitations on displaying content with nudity or adult themes. You might want to try searching for a specific artist known for such works (like Rubens or Rembrandt) or use more art-historical terms.`;
      } else {
        responseObject.response = `I couldn't find any artworks matching "${searchTerms}". Please try a different search term or browse our collection with a broader query.`;
      }
    } else if (claudeResponse) {
      responseObject.response = claudeResponse.content[0].text;
    } else {
      responseObject.response = `Here are some artworks related to "${searchTerms}" from the Rijksmuseum collection.`;
    }
    
    // Send response back to client
    console.log('Sending response back to client. Response size:', 
                JSON.stringify(responseObject).length, 'bytes');
    res.json(responseObject);
    console.log('Response sent successfully');
    
  } catch (error) {
    console.error('Error processing request:', error);
    res.status(500).json({ error: 'Failed to process your request' });
  }
});

// Helper function to detect Dutch text and translate to English
async function translateDutchToEnglish(text) {
  if (!text) return text;
  
  // Check if text might be Dutch (contains typical Dutch words or characters)
  const mightBeDutch = /\b(het|de|een|van|en|in|met|op|zijn|is|worden|zelf|voor|bij)\b/i.test(text) || 
                      /[àáâäèéêëìíîïòóôöùúûü]/i.test(text);
  
  if (mightBeDutch) {
    try {
      // Configure the translation
      translate.engine = 'google';
      translate.key = process.env.GOOGLE_TRANSLATE_API_KEY; // Optional: If you have a key
      
      const translated = await translate(text, { from: 'nl', to: 'en' });
      return translated;
    } catch (error) {
      console.error('Translation error:', error);
      return text; // Return original text if translation fails
    }
  }
  
  return text; // Return original text if not Dutch
}

// Direct API test endpoint (for debugging)
app.get('/api/test', (req, res) => {
  res.json({
    status: 'API is working',
    serverTime: new Date().toISOString(),
    headers: req.headers,
    cloudflare: req.headers['cf-ray'] ? true : false,
    source: req.headers['x-forwarded-for'] || req.ip,
    testData: {
      message: "This is test data from the API",
      success: true
    }
  });
});

// Fallback data for critical artworks
const CRITICAL_ARTWORKS = {
  'SK-A-3262': {
    artObject: {
      objectNumber: 'SK-A-3262',
      title: 'Self-portrait',
      principalOrFirstMaker: 'Vincent van Gogh',
      plaqueDescriptionEnglish: 'After he heard his brother Theo describe the new colourful style of French art Vincent decided in 1886 to move to Paris. He soon began experimenting with the new idiom in a series of self portraits. This was mainly to spare the expense of using models. Here he painted himself as a debonnaire Parisian with loose regular brushstrokes in striking colours.',
      physicalMedium: 'oil on cardboard',
      dimensions: [
        { unit: 'cm', type: 'height', value: '42' },
        { unit: 'cm', type: 'width', value: '34' },
        { unit: 'cm', type: 'depth', value: '8' }
      ],
      location: 'HG-1.18',
      subTitle: 'h 42cm × w 34cm × d 8cm',
      materials: ['cardboard', 'oil paint (paint)'],
      techniques: []
    }
  },
  'SK-C-5': {
    artObject: {
      objectNumber: 'SK-C-5',
      title: 'The Night Watch',
      principalOrFirstMaker: 'Rembrandt van Rijn',
      plaqueDescriptionEnglish: 'Rembrandt\'s largest, most famous canvas was made for the Arquebusiers guild hall. This was a civil militia group portrait, a popular genre in the 17th century Dutch Republic. Rembrandt departed from convention, which dictated that such groups be composed of rows of figures ranked according to seniority, and instead created a bustling scene of militiamen getting ready for action.',
      physicalMedium: 'oil on canvas',
      dimensions: [
        { unit: 'cm', type: 'height', value: '379.5' },
        { unit: 'cm', type: 'width', value: '453.5' },
        { unit: 'cm', type: 'depth', value: '17' }
      ],
      location: 'Night Watch Gallery',
      subTitle: 'h 379.5cm × w 453.5cm',
      materials: ['canvas', 'oil paint (paint)'],
      techniques: ['painting']
    }
  }
};

// Enhanced API endpoint for artwork details with fallbacks for Cloudflare tunnel
app.get('/api/artwork/:objectNumber', async (req, res) => {
  const { objectNumber } = req.params;
  
  console.log('Received artwork details request for:', objectNumber);
  console.log('Request URL:', req.originalUrl);
  console.log('Request headers:', req.headers);
  
  // Add Cloudflare-specific cache busting headers
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.setHeader('CF-Cache-Status', 'BYPASS');
  res.setHeader('X-Response-Time', Date.now().toString());
  
  // Check if request is coming from a proxy or custom hostname
  const hostname = process.env.HOSTNAME || ''; // Get hostname from env
  const isProxy = req.headers['cf-ray'] || // Cloudflare specific header 
                 (hostname && req.headers.host && req.headers.host.includes(hostname));
  console.log(`Request is ${isProxy ? 'from proxy/custom domain' : 'direct'}`);
  
  // If this is a critical artwork and it's coming from a proxy, use our fallback data
  if (isProxy && CRITICAL_ARTWORKS[objectNumber]) {
    console.log('Using fallback data for proxy/custom domain request');
    return res.json(CRITICAL_ARTWORKS[objectNumber]);
  }
  
  try {
    console.log('Fetching artwork details from Rijksmuseum API...');
    const details = await getArtworkDetails(objectNumber);
    console.log('Successfully fetched artwork details');
    
    // Update the response object with the processed data
    details.artObject = {
      ...details.artObject,
      // Ensure all required fields are present with proper fallbacks
      plaqueDescriptionEnglish: details.artObject.plaqueDescriptionEnglish || details.artObject.scLabelLine || details.artObject.title || '',
      physicalMedium: details.artObject.physicalMedium || 
                     (details.artObject.materials?.length ? details.artObject.materials.join(', ') : '') ||
                     (details.artObject.techniques?.length ? details.artObject.techniques.join(', ') : '') || '',
      dimensions: details.artObject.dimensions || [],
      location: details.artObject.location || details.artObject.currentLocation || details.artObject.gallery || '',
      subTitle: details.artObject.subTitle || ''
    };

    // Log the final response structure
    console.log('Final response structure:', {
      plaqueDescriptionEnglish: details.artObject.plaqueDescriptionEnglish?.substring(0, 100) + '...',
      physicalMedium: details.artObject.physicalMedium,
      dimensions: details.artObject.dimensions,
      location: details.artObject.location,
      subTitle: details.artObject.subTitle
    });
    
    res.json(details);
  } catch (error) {
    console.error('Error fetching artwork details:', error);
    
    // If we have a fallback for this artwork, use it
    if (CRITICAL_ARTWORKS[objectNumber]) {
      console.log('Using fallback data due to API error');
      res.json(CRITICAL_ARTWORKS[objectNumber]);
    } else {
      // Return a generic response with basic data
      res.json({
        artObject: {
          objectNumber: objectNumber,
          title: 'Artwork information temporarily unavailable',
          plaqueDescriptionEnglish: 'The detailed information for this artwork is currently unavailable. Please try again later.',
          physicalMedium: 'Information not available',
          dimensions: [],
          location: 'Information not available',
          subTitle: ''
        }
      });
    }
  }
});

// Cache-busting route for when updates are made
app.get('/refresh', (req, res) => {
  // Set strict no-cache headers for all resources
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  
  // Send a special version of index.html with meta refresh
  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta http-equiv="refresh" content="1;url=/">
      <title>Refreshing...</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; padding-top: 50px; }
      </style>
    </head>
    <body>
      <h2>Refreshing site with latest updates...</h2>
      <p>You will be redirected in a moment.</p>
      <script>
        // Clear browser cache for this site
        window.onload = function() {
          localStorage.clear();
          sessionStorage.clear();
          setTimeout(function() {
            window.location.href = '/?nocache=' + Date.now();
          }, 1000);
        }
      </script>
    </body>
    </html>
  `;
  
  res.send(htmlContent);
});

// Fallback route for SPA
app.get('*', (req, res) => {
  res.sendFile(join(__dirname, 'index.html'));
});

// Start server
app.listen(PORT, HOST, () => {
  console.log(`Server running on ${HOST}:${PORT}`);
  console.log(`Local access: http://localhost:${PORT}`);
  
  // Only show this message if we're binding to all interfaces
  if (HOST === '0.0.0.0') {
    console.log(`For external access, use your device's IP address and port ${PORT}`);
  }
});
