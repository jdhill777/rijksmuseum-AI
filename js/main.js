// Debug utility to verify CSS transition loading
function verifyCssTransitions() {
    console.log('CSS Transition Check: Started');
    
    // Check if CSS variables are loaded properly
    const root = document.documentElement;
    const computedStyle = getComputedStyle(root);
    
    // Check key CSS variables
    const accentColor = computedStyle.getPropertyValue('--accent-color').trim();
    const accentColorRgb = computedStyle.getPropertyValue('--accent-color-rgb').trim();
    const transitionSpeed = computedStyle.getPropertyValue('--transition-speed').trim();
    const shimmerSpeed = computedStyle.getPropertyValue('--shimmer-speed').trim();
    
    console.log('CSS Variables Check:', {
        accentColor,
        accentColorRgb,
        transitionSpeed,
        shimmerSpeed
    });
    
    // Force a reflow for any messages that should have shimmer
    const assistantMessages = document.querySelectorAll('.message.assistant .message-content');
    assistantMessages.forEach(msg => {
        // Force a reflow
        window.getComputedStyle(msg).opacity;
    });
    
    // Check animation state
    const hasShimmerAnimation = document.querySelector('.message.assistant .message-content')?.classList.contains('shimmer-effect');
    
    console.log('CSS Transition Check: Completed', {
        assistantMessagesCount: assistantMessages.length,
        hasShimmerAnimation
    });
    
    // Create a test element to verify animations are working
    const testElement = document.createElement('div');
    testElement.style.cssText = `
        position: fixed; 
        top: -100px; 
        left: -100px;
        width: 10px; 
        height: 10px; 
        background: ${accentColor};
        animation: shimmer 4s infinite;
        transition: opacity 0.3s ease;
        z-index: -1;
        opacity: 0.01;
    `;
    document.body.appendChild(testElement);
    
    // Force animation to run
    window.getComputedStyle(testElement).animationName;
    
    // Clean up after 5 seconds
    setTimeout(() => testElement.remove(), 5000);
}

document.addEventListener('DOMContentLoaded', () => {
    // Run CSS transition verification
    verifyCssTransitions();
    
    
    // Theme Toggle Functionality
    const themeToggle = document.getElementById('theme-toggle');
    const themeIcon = themeToggle.querySelector('i');
    
    // Check for saved user preference, default to dark
    const savedTheme = localStorage.getItem('theme') || 'dark';
    document.body.dataset.theme = savedTheme;
    updateThemeIcon(savedTheme);
    
    // Toggle theme
    themeToggle.addEventListener('click', () => {
        const currentTheme = document.body.dataset.theme;
        const newTheme = currentTheme === 'light' ? 'dark' : 'light';
        
        document.body.dataset.theme = newTheme;
        localStorage.setItem('theme', newTheme);
        updateThemeIcon(newTheme);
    });
    
    function updateThemeIcon(theme) {
        if (theme === 'dark') {
            themeIcon.classList.remove('fa-moon');
            themeIcon.classList.add('fa-sun');
        } else {
            themeIcon.classList.remove('fa-sun');
            themeIcon.classList.add('fa-moon');
        }
    }
    
    // DOM Elements
    const userInput = document.getElementById('user-input');
    const submitButton = document.getElementById('submit-button');
    const messageContainer = document.getElementById('message-container');
    const artworkGallery = document.getElementById('artwork-gallery');
    const modal = document.getElementById('artwork-modal');
    const closeButton = document.querySelector('.close-button');
    const modalImage = document.getElementById('modal-image');
    const modalTitle = document.getElementById('modal-title');
    const modalArtist = document.getElementById('modal-artist');
    const modalDate = document.getElementById('modal-date');
    const modalDescription = document.getElementById('modal-description');
    const modalDimensions = document.getElementById('modal-dimensions');
    const exploreSimilarBtn = document.getElementById('explore-similar');
    const footer = document.querySelector('footer');
    
    // Fullscreen elements
    const fullscreenContainer = document.getElementById('fullscreen-container');
    const fullscreenImage = document.getElementById('fullscreen-image');
    const fullscreenCaption = document.getElementById('fullscreen-caption');
    const fullscreenExit = document.getElementById('fullscreen-exit');
    
    // Initialize footer position - starts fixed at the bottom
    footer.classList.remove('below-gallery');

    // Store current artwork for explore similar functionality
    let currentArtwork = null;
    
    // Store search state for pagination
    let searchState = {
        currentQuery: '',
        page: 1,
        hasMoreResults: false,
        isLoading: false
    };

    // API endpoint - auto-detect baseURL whether on localhost or external IP
    const getBaseUrl = () => {
        // Get the current protocol and host (will work for both localhost and external IP)
        return window.location.protocol + '//' + window.location.host;
    };
    
    const API_URL = `${getBaseUrl()}/api/chat`;
    const API_ARTWORK_URL = `${getBaseUrl()}/api/artwork`;
    
    // Log connectivity info for debugging
    console.log('Using API endpoints:', {
        chat: API_URL,
        artwork: API_ARTWORK_URL,
        baseUrl: getBaseUrl()
    });
    
    // Event Listeners
submitButton.addEventListener('click', () => {
    console.log('Submit button clicked');
    
    // Get the current input value
    const inputValue = userInput.value.trim();
    console.log('[INPUT VALUE]:', inputValue);
    
    // Handle empty search
    if (!inputValue) {
        console.log('[EMPTY SEARCH] - Using default Van Gogh query');
        userInput.value = "Show me paintings by Van Gogh";
        handleSubmit();
        return;
    }
    
    // Handle normal search
    console.log('[REGULAR SEARCH] - Submitting current input');
    handleSubmit();
});
    
    // Handle key events in the input field - Fix for Enter key detection
    console.log('Setting up input field event listeners');
    userInput.addEventListener('keydown', function keydownHandler(e) {
        // Log the key event first
        console.log('[KEYDOWN EVENT]', e.key, 'pressed');
        
        if (e.key === 'Enter' && !e.shiftKey) {
            // Prevent form submission
            e.preventDefault();
            e.stopPropagation();
            
            console.log('[ENTER PRESSED] - Handling search');
            
            // Get the current input value
            const inputValue = userInput.value.trim();
            console.log('[INPUT VALUE]:', inputValue);
            
            // Handle empty search
            if (!inputValue) {
                console.log('[EMPTY SEARCH] - Using default Van Gogh query');
                userInput.value = "Show me paintings by Van Gogh";
                handleSubmit();
                return;
            }
            
            // Handle normal search
            console.log('[REGULAR SEARCH] - Submitting current input');
            handleSubmit();
        }
    });

    closeButton.addEventListener('click', () => {
        // Fade out transitions
        modal.classList.remove('active');
        document.querySelector('.modal-content').classList.remove('active');
        
        // Wait for the transition to complete before hiding the modal
        setTimeout(() => {
            modal.style.display = 'none';
        }, 400); // Match the transition duration
    });

    window.addEventListener('click', (e) => {
        if (e.target === modal) {
            // Fade out transitions
            modal.classList.remove('active');
            document.querySelector('.modal-content').classList.remove('active');
            
            // Wait for the transition to complete before hiding the modal
            setTimeout(() => {
                modal.style.display = 'none';
            }, 400); // Match the transition duration
        }
    });
    
    // Explore Similar functionality
    exploreSimilarBtn.addEventListener('click', () => {
        if (currentArtwork) {
            // First fade out the modal with transitions
            modal.classList.remove('active');
            document.querySelector('.modal-content').classList.remove('active');
            
            // Fade out existing gallery items if any
            const existingCards = document.querySelectorAll('.artwork-card');
            existingCards.forEach(card => {
                card.style.opacity = '0';
                card.style.transform = 'translateY(20px)';
            });
            
            // Construct search query based on artwork details
            const searchTerms = [];
            if (currentArtwork.title) {
                // Extract key terms from title, excluding common words
                const titleTerms = currentArtwork.title.toLowerCase()
                    .split(' ')
                    .filter(word => word.length > 3 && !['the', 'and', 'with', 'from'].includes(word))
                    .slice(0, 2);
                searchTerms.push(...titleTerms);
            }
            if (currentArtwork.principalOrFirstMaker) {
                searchTerms.push(currentArtwork.principalOrFirstMaker);
            }
            
            // Wait for transitions to complete before continuing
            setTimeout(() => {
                // Hide modal
                modal.style.display = 'none';
                
                // Clear existing artwork gallery
                artworkGallery.innerHTML = '';
                
                // Set the search input and trigger search
                userInput.value = `Show me artworks similar to ${searchTerms.join(' ')}`;
                handleSubmit();
            }, 400); // Match transition duration
        }
    });
    
    // Fullscreen functionality
    modalImage.addEventListener('click', enterFullscreen);
    document.querySelector('.fullscreen-hint').addEventListener('click', enterFullscreen);
    fullscreenExit.addEventListener('click', exitFullscreen);
    fullscreenContainer.addEventListener('click', (e) => {
        if (e.target === fullscreenContainer) {
            exitFullscreen();
        }
    });
    
    // Also support ESC key to exit fullscreen
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && fullscreenContainer.style.display === 'flex') {
            exitFullscreen();
        }
    });
    
// Store the scroll position globally so we can restore it when exiting fullscreen
let savedScrollPosition = 0;

function enterFullscreen() {
    // Save current scroll position before entering fullscreen
    savedScrollPosition = window.scrollY || window.pageYOffset;
    console.log('Entering fullscreen, saving scroll position:', savedScrollPosition);
    
    // Set the image source - ensure it loads before transitioning
    fullscreenImage.onload = function() {
        console.log('Fullscreen image loaded successfully');
    };
    fullscreenImage.onerror = function() {
        console.error('Failed to load fullscreen image');
    };
    fullscreenImage.src = modalImage.src;
    fullscreenImage.alt = modalImage.alt;
    
    // Don't set caption text in fullscreen mode
    fullscreenCaption.style.display = 'none';
    
    // Configure the fullscreen container for proper viewport centering
    fullscreenContainer.style.position = 'fixed';
    fullscreenContainer.style.top = '0';
    fullscreenContainer.style.left = '0';
    fullscreenContainer.style.right = '0';
    fullscreenContainer.style.bottom = '0';
    fullscreenContainer.style.width = '100vw';
    fullscreenContainer.style.height = '100vh';
    fullscreenContainer.style.padding = '0';
    fullscreenContainer.style.margin = '0';
    fullscreenContainer.style.display = 'flex';
    fullscreenContainer.style.justifyContent = 'center';
    fullscreenContainer.style.alignItems = 'center';
    fullscreenContainer.style.zIndex = '9999';
    
    // Prevent scrolling while in fullscreen mode
    document.body.classList.add('fullscreen-active');
    
    // Ensure footer is not visible in fullscreen
    footer.style.zIndex = '1';
    
    // Make container visible immediately to ensure the image appears
    fullscreenContainer.style.display = 'flex';
    
    // Initialize opacity to 0 for transition
    fullscreenContainer.style.opacity = '0';
    
    // Prepare fullscreen image - ensure it stays in the viewport
    fullscreenImage.style.maxWidth = '95vw';
    fullscreenImage.style.maxHeight = '85vh';
    fullscreenImage.style.objectFit = 'contain';
    fullscreenImage.style.margin = '0 auto';
    fullscreenImage.style.display = 'block';
    fullscreenImage.style.transform = 'scale(0.95)'; // Start slightly smaller
    
    // Position fullscreen controls
    const controls = document.querySelector('.fullscreen-controls');
    if (controls) {
        controls.style.position = 'absolute';
        controls.style.top = '20px';
        controls.style.right = '20px';
        controls.style.zIndex = '10000';
        controls.style.opacity = '0'; // Start hidden
    }
    
    // Add the active class to enable CSS transitions
    fullscreenContainer.classList.add('active');
    
    // Wait a tiny bit to ensure elements are rendered before starting transitions
    setTimeout(() => {
        // Set transitions AFTER elements are in the DOM
        fullscreenContainer.style.transition = 'opacity 0.8s ease-in';
        fullscreenImage.style.transition = 'transform 0.6s ease-in';
        if (controls) {
            controls.style.transition = 'opacity 0.6s ease-in';
        }
        
        // Force a reflow to make transitions work
        window.getComputedStyle(fullscreenContainer).opacity;
        
        // Now trigger all the transitions
        fullscreenContainer.style.opacity = '1';
        fullscreenImage.style.transform = 'scale(1)';
        if (controls) {
            controls.style.opacity = '1';
        }
        
        // Reset scroll position to top
        window.scrollTo(0, 0);
        
        console.log('Fullscreen transitions started');
    }, 20);
}
    
function exitFullscreen() {
    console.log('Exiting fullscreen, will restore to scroll position:', savedScrollPosition);
    
    // Remove active class to trigger exit transitions
    fullscreenContainer.classList.remove('active');
    
    // First phase: fade out the fullscreen view with a longer duration
    fullscreenContainer.style.transition = 'opacity 0.8s ease-out';
    
    // Wait for the first phase of transition to progress before hiding
    setTimeout(() => {
        // Hide the container and restore body scrolling
        fullscreenContainer.style.display = 'none';
        document.body.classList.remove('fullscreen-active');
        footer.style.zIndex = '50'; // Restore footer z-index
        
        // Add a transition to the body for smoother scrolling
        document.body.style.scrollBehavior = 'smooth';
        
        // Second phase: smoothly scroll back to the previous position
        window.scrollTo({
            top: savedScrollPosition,
            behavior: 'smooth' // Use smooth scrolling for a more natural transition
        });
        
        console.log('Smoothly restoring scroll position after exiting fullscreen');
        
        // Reset the scroll behavior after transition completes
        setTimeout(() => {
            document.body.style.scrollBehavior = '';
        }, 800); // Match the scroll transition duration
        
    }, 600); // Increased from 400ms to 600ms for a less jarring transition
}

    // Helper function for fetch with timeout - 60 second timeout for mobile
    const fetchWithTimeout = async (url, options, timeout = 60000) => {
        console.log(`Fetch request to ${url} with timeout ${timeout}ms`);
        const controller = new AbortController();
        const id = setTimeout(() => {
            console.log(`Request timeout reached for ${url}`);
            controller.abort();
        }, timeout);
        
        try {
            const response = await fetch(url, {
                ...options,
                signal: controller.signal
            });
            clearTimeout(id);
            console.log(`Fetch completed successfully for ${url}`);
            return response;
        } catch (error) {
            clearTimeout(id);
            console.error(`Fetch error for ${url}:`, error.name, error.message);
            throw error;
        }
    };

    // Functions
    async function handleSubmit(isLoadMore = false) {
        console.log('==== handleSubmit START ====');
        console.log('isLoadMore =', isLoadMore);
        console.log('Current input value =', userInput.value);
        
        // If this is a new search (not loading more), reset search state
        if (!isLoadMore) {
            searchState.page = 1;
            searchState.hasMoreResults = false;
            
            // Disable search button and input while processing
            submitButton.disabled = true;
            submitButton.style.opacity = '0.6';
            submitButton.style.cursor = 'not-allowed';
            userInput.disabled = true;
            console.log('Disabled input and submit button');
        } else {
            // If loading more, increment the page
            searchState.page++;
            
            // Disable the load more button
            const loadMoreBtn = document.getElementById('load-more-button');
            if (loadMoreBtn) {
                loadMoreBtn.disabled = true;
                loadMoreBtn.textContent = 'Loading...';
                loadMoreBtn.style.opacity = '0.6';
                loadMoreBtn.style.cursor = 'not-allowed';
            }
        }
        
        searchState.isLoading = true;
        
        // Get the message from the input or from search state if loading more
        let message = isLoadMore ? searchState.currentQuery : userInput.value.trim();
        console.log('Initial message value:', JSON.stringify(message), 'length:', (message || '').length);
        
        // Use default Van Gogh search if:
        // 1. This is a new search (not loading more)
        // 2. AND the input is empty
        if (!isLoadMore && !message) {
            // Set the default query
            message = "Show me paintings by Van Gogh";
            console.log('EMPTY SEARCH DETECTED -> Using default search:', message);
            
            // Display what we're searching for briefly to inform the user
            userInput.value = message;
            userInput.disabled = false; // Temporarily enable to update value
            
            // Wait a moment so the user can see what's being searched
            setTimeout(() => {
                userInput.value = '';
                userInput.disabled = true; // Disable again during search
            }, 300);
        }
        
        // Add user message to chat only if this is a new search
        if (!isLoadMore) {
            // Store the current query for pagination
            searchState.currentQuery = message;
            addMessage(message, 'user');
        }
        
        // Clear input
        userInput.value = '';
        
        // Handle gallery differently based on whether we're loading more or starting fresh
        if (!isLoadMore) {
            // Fade out existing gallery items if any
            const existingCards = document.querySelectorAll('.artwork-card');
            if (existingCards.length > 0) {
                // Add transition to fade out existing items
                existingCards.forEach(card => {
                    card.style.opacity = '0';
                    card.style.transform = 'translateY(20px)';
                });
                
                // Wait for transition to complete before clearing gallery
                setTimeout(() => {
                    // Clear existing gallery content when a new prompt is entered
                    artworkGallery.innerHTML = '';
                    
                    // Remove any load more button
                    const loadMoreBtn = document.getElementById('load-more-button');
                    if (loadMoreBtn) loadMoreBtn.remove();
                }, 300);
            } else {
                // If no existing cards, just clear the gallery immediately
                artworkGallery.innerHTML = '';
                
                // Remove any load more button
                const loadMoreBtn = document.getElementById('load-more-button');
                if (loadMoreBtn) loadMoreBtn.remove();
            }
        }
        
        // Reset footer position to fixed at bottom when a new search starts (not when loading more)
        if (!isLoadMore) {
            footer.classList.remove('below-gallery');
        }
        
        // Show loading message only for new searches
        const loadingId = isLoadMore ? null : addLoadingMessage();
        
        try {
            // Log parameters being sent to API for debugging
            console.log('Sending API request with parameters:', {
                message,
                page: searchState.page,
                isLoadMore
            });
            
            // Create a debug id to track this request through logs
            const requestId = Date.now();
            
            // Send message to API with timeout, including pagination parameter
            const response = await fetchWithTimeout(API_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Request-ID': requestId.toString()
                },
                body: JSON.stringify({ 
                    message,
                    page: searchState.page,
                    requestId
                })
            });
            
            if (!response.ok) {
                throw new Error(`Server responded with status: ${response.status}`);
            }
            
            const data = await response.json();
            
            // Remove loading message if this is a new search
            if (loadingId) {
                removeLoadingMessage(loadingId);
            }
            
            // Reset loading state
            searchState.isLoading = false;
            
            // Re-enable search button and input if this is a new search
            if (!isLoadMore) {
                submitButton.disabled = false;
                submitButton.style.opacity = '1';
                submitButton.style.cursor = 'pointer';
                userInput.disabled = false;
            } else {
                // Re-enable load more button or remove it
                const loadMoreBtn = document.getElementById('load-more-button');
                if (loadMoreBtn) {
                    loadMoreBtn.disabled = false;
                    loadMoreBtn.textContent = 'Load More Artworks';
                    loadMoreBtn.style.opacity = '1';
                    loadMoreBtn.style.cursor = 'pointer';
                }
            }
            
            // Add assistant response to chat if available (only for new searches)
            if (!isLoadMore) {
                if (data.response) {
                    addMessage(data.response, 'assistant');
                } else {
                    // Fallback response if Claude is not available
                    addMessage(`Searching for artworks related to "${message}"...`, 'assistant');
                }
            }
            
            // Check if there are artworks and if there might be more to load
            if (data.artworks) {
                // Update hasMoreResults flag from API response (if available)
                searchState.hasMoreResults = data.hasMoreResults || data.artworks.length >= 10; // Assume there's more if we got 10+ results
                console.log('hasMoreResults:', searchState.hasMoreResults, 'artworks length:', data.artworks.length);
                
            // Extra debug logging
            console.log('Received artworks data:', {
                responseSize: JSON.stringify(data).length,
                artworksCount: data.artworks.length,
                firstArtwork: data.artworks[0]
            });
            
            // Display the artworks (append or replace based on isLoadMore)
            displayArtworks(data.artworks, isLoadMore);
                
                // If no artworks found on first search, show a message but keep footer at bottom
                if (data.artworks.length === 0 && !isLoadMore) {
                    addMessage('No artworks found matching your search. Try a different query.', 'assistant');
                }
                
                // Add or update Load More button if there may be more results
                if (data.artworks.length > 0) {
                    // Force a short delay to ensure animations complete first
                    setTimeout(() => {
                        updateLoadMoreButton();
                    }, 500);
                }
            }
            
        } catch (error) {
            console.error('Error:', error);
            
            // Remove loading message if this is a new search
            if (loadingId) {
                removeLoadingMessage(loadingId);
            }
            
            // Reset loading state
            searchState.isLoading = false;
            
            // Re-enable search button and input if this is a new search
            if (!isLoadMore) {
                submitButton.disabled = false;
                submitButton.style.opacity = '1';
                submitButton.style.cursor = 'pointer';
                userInput.disabled = false;
            } else {
                // Remove load more button if there was an error
                const loadMoreBtn = document.getElementById('load-more-button');
                if (loadMoreBtn) {
                    loadMoreBtn.remove();
                }
            }
            
            // Simple connection error message that encourages retry
            addMessage('Sorry, there was a problem connecting to the server. Please try again in a moment.', 'assistant');
        }
    }

    function addMessage(content, sender) {
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${sender}`;
        
        const messageContent = document.createElement('div');
        messageContent.className = 'message-content';
        
        // Add to DOM immediately but hide content
        messageDiv.appendChild(messageContent);
        messageContainer.appendChild(messageDiv);
        
        // Handle multiline messages and markdown-like formatting
        const paragraphs = content.split('\n\n');
        
        // Prepare paragraphs for typing animation
        let allParagraphs = [];
        paragraphs.forEach(paragraph => {
            if (paragraph.trim()) {
                const p = document.createElement('p');
                p.className = 'typing-text';
                p.style.opacity = '0';
                messageContent.appendChild(p);
                allParagraphs.push({ element: p, text: paragraph });
            }
        });
        
    // Start the typing animation - 300% faster
    typeTextSequentially(allParagraphs, 0, 8, () => {
        // Scroll to bottom when typing is done
        messageContainer.scrollTop = messageContainer.scrollHeight;
        
        // If this is an assistant message, check if we should display artworks
        if (sender === 'assistant' && artworkGallery.children.length > 0) {
            // Call animateArtworkGallery only after all text is typed
            animateArtworkGallery();
        }
    });
        
        // Scroll to see start of message
        messageContainer.scrollTop = messageContainer.scrollHeight;
    }
    
    function typeTextSequentially(paragraphs, paragraphIndex, speed, onComplete) {
        if (paragraphIndex >= paragraphs.length) {
            if (onComplete) onComplete();
            return;
        }
        
        const currentPara = paragraphs[paragraphIndex];
        currentPara.element.style.opacity = '1';
        currentPara.element.textContent = '';
        
        // Type the current paragraph
        let charIndex = 0;
        const typeInterval = setInterval(() => {
            if (charIndex < currentPara.text.length) {
                currentPara.element.textContent += currentPara.text.charAt(charIndex);
                
                // Auto-scroll to keep current text in view
                const messageContainer = document.getElementById('message-container');
                if (messageContainer) {
                    // Check if we need to scroll by seeing if the current paragraph is close to or beyond the bottom
                    const containerRect = messageContainer.getBoundingClientRect();
                    const paraRect = currentPara.element.getBoundingClientRect();
                    
                    // If the paragraph bottom is beyond the container's visible area
                    if (paraRect.bottom > containerRect.bottom - 50) {
                        // Scroll to keep current text in view with a slight offset
                        messageContainer.scrollTop = messageContainer.scrollHeight;
                    }
                }
                
                charIndex++;
            } else {
                clearInterval(typeInterval);
                
                // Always scroll to make sure we can see the completed paragraph
                const messageContainer = document.getElementById('message-container');
                if (messageContainer) {
                    messageContainer.scrollTop = messageContainer.scrollHeight;
                }
                
                // Move to next paragraph after small delay
                setTimeout(() => {
                    typeTextSequentially(paragraphs, paragraphIndex + 1, speed, onComplete);
                }, 100);
            }
        }, speed);
    }

    function addLoadingMessage() {
        const loadingId = Date.now();
        
        const messageDiv = document.createElement('div');
        messageDiv.className = 'message assistant message-loading';
        messageDiv.dataset.loadingId = loadingId;
        
        const messageContent = document.createElement('div');
        messageContent.className = 'message-content message-loading-text';
        
        const loadingSpinner = document.createElement('div');
        loadingSpinner.className = 'loading-spinner';
        
        const loadingText = document.createElement('span');
        loadingText.textContent = 'Searching for artworks with Claude AI... This may take a moment.';
        
        messageContent.appendChild(loadingSpinner);
        messageContent.appendChild(loadingText);
        messageDiv.appendChild(messageContent);
        
        messageContainer.appendChild(messageDiv);
        
        // Scroll to bottom
        messageContainer.scrollTop = messageContainer.scrollHeight;
        
        return loadingId;
    }

    function removeLoadingMessage(loadingId) {
        const loadingMessage = document.querySelector(`.message[data-loading-id="${loadingId}"]`);
        if (loadingMessage) {
            loadingMessage.remove();
        }
    }

    function displayArtworks(artworks, append = false) {
        console.log(`Displaying ${artworks.length} artworks, append mode: ${append}`);
        
        // More detailed logging of artworks
        if (artworks.length > 0) {
            console.log('First artwork details:', {
                title: artworks[0].title,
                artist: artworks[0].principalOrFirstMaker,
                hasImage: !!(artworks[0].webImage && artworks[0].webImage.url)
            });
        }
        
        // Count existing cards before any changes (for debugging and appending)
        const existingCardCount = artworkGallery.querySelectorAll('.artwork-card').length;
        console.log(`Existing cards before update: ${existingCardCount}`);
        
        // If not appending, clear existing gallery including load more button
        if (!append) {
            // Remove load more button if it exists
            const loadMoreBtn = document.getElementById('load-more-button');
            if (loadMoreBtn) {
                const container = loadMoreBtn.parentElement;
                if (container) container.remove();
            }
            
            // Clear the gallery
            artworkGallery.innerHTML = '';
            console.log('Cleared gallery for new search');
        } else {
            // Remove just the load more button when appending
            const loadMoreBtn = document.getElementById('load-more-button');
            if (loadMoreBtn) {
                const container = loadMoreBtn.parentElement;
                if (container) container.remove();
            }
            console.log('Removed load more button for appending new results');
        }
        
        // Create all cards but keep them hidden
        artworks.forEach((artwork, index) => {
            const artworkCard = document.createElement('div');
            artworkCard.className = 'artwork-card fade-in';
            // Initially hide the card
            artworkCard.style.opacity = '0';
            artworkCard.style.transform = 'translateY(20px)';
            // Set a delay based on index
            artworkCard.style.transitionDelay = `${index * 100}ms`;
            
            artworkCard.addEventListener('click', () => {
                console.log('Clicked artwork:', {
                    title: artwork.title,
                    objectNumber: artwork.objectNumber,
                    fullArtwork: artwork
                });
                showArtworkDetails(artwork);
            });
            
            const image = document.createElement('img');
            image.className = 'artwork-image';
            
            // Track if we have a primary image URL
            const hasPrimaryImage = artwork.webImage && artwork.webImage.url;
            
            if (hasPrimaryImage) {
                // If artwork has an image, use it
                image.src = artwork.webImage.url;
                
                // Handle image loading errors
                image.onerror = function() {
                    console.log(`Image failed to load for: ${artwork.title}`);
                    // Use Rijksmuseum logo as fallback
                    image.src = 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/Logo_Rijksmuseum.svg/799px-Logo_Rijksmuseum.svg.png';
                    image.classList.add('no-image');
                };
            } else {
                // If no image available, use default logo
                image.src = 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/Logo_Rijksmuseum.svg/799px-Logo_Rijksmuseum.svg.png';
                image.classList.add('no-image');
            }
            
            image.alt = artwork.title;
            image.loading = 'lazy';
            
            const infoDiv = document.createElement('div');
            infoDiv.className = 'artwork-info';
            
            const title = document.createElement('h3');
            title.className = 'artwork-title';
            title.textContent = artwork.title;
            
            const artist = document.createElement('p');
            artist.className = 'artwork-artist';
            artist.textContent = artwork.principalOrFirstMaker;
            
            const date = document.createElement('p');
            date.className = 'artwork-date';
            // Extract date from longTitle if possible
            const dateMatch = artwork.longTitle.match(/\d{4}/);
            date.textContent = dateMatch ? dateMatch[0] : '';
            
            infoDiv.appendChild(title);
            infoDiv.appendChild(artist);
            if (dateMatch) infoDiv.appendChild(date);
            
            artworkCard.appendChild(image);
            artworkCard.appendChild(infoDiv);
            
            artworkGallery.appendChild(artworkCard);
        });
    }
    
    function animateArtworkGallery() {
        console.log('animateArtworkGallery called');
        
        // Get all artwork cards that are not yet animated
        const cards = document.querySelectorAll('.artwork-card:not(.animated)');
        console.log(`Found ${cards.length} artwork cards to animate`);
        
        // Force a reflow to ensure transitions work
        window.getComputedStyle(artworkGallery).opacity;
        
        // Animate each card with a staggered delay
        cards.forEach((card, index) => {
            setTimeout(() => {
                console.log(`Animating card ${index+1}/${cards.length}`);
                card.style.opacity = '1';
                card.style.transform = 'translateY(0)';
            }, 100 * index);
        });
        
        // Scroll to the gallery
        setTimeout(() => {
            console.log('Scrolling to gallery and adjusting footer');
            artworkGallery.scrollIntoView({ behavior: 'smooth', block: 'start' });
            
            // Position footer below gallery content once artwork is displayed
            footer.classList.add('below-gallery');
            
            // Mark cards as animated
            cards.forEach(card => card.classList.add('animated'));
        }, 300);
    }
    
    // Function to add/update the Load More button (disabled per user request)
    function updateLoadMoreButton() {
        // Remove any existing load more button
        const existingButton = document.getElementById('load-more-button');
        if (existingButton) {
            existingButton.remove();
        }
        
        // Load More button functionality has been removed
        console.log('Load More button functionality removed per user request');
    }

    async function showArtworkDetails(artwork) {
        console.log('Opening artwork details for:', artwork);
        
        // Store current artwork for explore similar functionality
        currentArtwork = artwork;
        
        // Get the current scroll position
        const scrollY = window.scrollY || window.pageYOffset;
        
        // First show the modal without activation
        modal.style.display = 'block';
        const modalContentEl = document.querySelector('.modal-content');
        
        // Position the modal content relative to current scroll position
        const viewportHeight = window.innerHeight;
        // Aim to center the modal in the current viewport
        modalContentEl.style.marginTop = Math.max(20, scrollY + (viewportHeight * 0.1)) + 'px';
        modalContentEl.style.marginBottom = '5vh';
        
        // Force a reflow for transition to work
        window.getComputedStyle(modal).opacity;
        
        // Trigger transitions by adding active class
        modal.classList.add('active');
        modalContentEl.classList.add('active');
        
        // Scroll to make sure the modal is visible
        modalContentEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
        
        console.log('Object number:', artwork.objectNumber);
        
        // Set basic info
        modalTitle.textContent = artwork.title;
        modalArtist.textContent = artwork.principalOrFirstMaker;
        
        // Extract date from longTitle if possible
        const dateMatch = artwork.longTitle.match(/\d{4}/);
        modalDate.textContent = dateMatch ? dateMatch[0] : '';
        
        // Set image - images load quickly so no need for loading overlay
        if (artwork.webImage && artwork.webImage.url) {
            modalImage.src = artwork.webImage.url;
            modalImage.alt = artwork.title;
            modalImage.classList.remove('no-image');
            modalImage.style.cursor = 'zoom-in';
            document.querySelector('.fullscreen-hint').style.display = 'block';
            
            // Add error handler for modal image
            modalImage.onerror = function() {
                console.log(`Modal image failed to load for: ${artwork.title}`);
                // Use Rijksmuseum logo as fallback
                modalImage.src = 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/Logo_Rijksmuseum.svg/799px-Logo_Rijksmuseum.svg.png';
                modalImage.classList.add('no-image');
            };
        } else {
            // If no image available, use default logo
            modalImage.src = 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/Logo_Rijksmuseum.svg/799px-Logo_Rijksmuseum.svg.png';
            modalImage.classList.add('no-image');
        }
        
        // Show loading state for description and technical details
        modalDescription.innerHTML = '<div class="loading-spinner"></div>';
        
        // Setup technical details section with loading state
        const technicalDetailsDiv = document.querySelector('.technical-details');
        technicalDetailsDiv.innerHTML = `
            <div class="loading-state">
                <div class="loading-spinner"></div>
                <p>Loading artwork details...</p>
            </div>
            <div id="modal-dimensions"><strong>Size:</strong> Loading...</div>
            <div id="modal-materials"><strong>Medium:</strong> Loading...</div>
            <div id="modal-location"><strong>Location:</strong> Loading...</div>
        `;

        // Get references to the technical detail elements
        const dimensionsElement = document.getElementById('modal-dimensions');
        const materialsElement = document.getElementById('modal-materials');
        const locationElement = document.getElementById('modal-location');
        
        // Fetch artwork details immediately
        if (artwork.objectNumber) {
            console.log('Fetching details for artwork:', artwork.objectNumber);
            console.log('API URL:', `${API_ARTWORK_URL}/${artwork.objectNumber}`);
            
            try {
                // Fetch artwork details with proper timeout
                const detailsUrl = `${API_ARTWORK_URL}/${artwork.objectNumber}`;
                console.log('Making API request to:', detailsUrl);
                
                // Log the full request details
                const requestOptions = {
                    method: 'GET',
                    headers: {
                        'Accept': 'application/json'
                    }
                };
                console.log('Request options:', requestOptions);
                
                const response = await fetchWithTimeout(detailsUrl, requestOptions, 30000);
                console.log('Response status:', response.status);
                console.log('Response headers:', response.headers);
                
                // Log the raw response
                const responseText = await response.text();
                console.log('Raw response:', responseText);
                
                // Parse the response
                const detailsData = JSON.parse(responseText);
                console.log('Parsed response:', detailsData);
                
                if (!response.ok) {
                    throw new Error(`Server responded with status: ${response.status}`);
                }
                
                if (!detailsData.artObject) {
                    throw new Error('Invalid API response - missing artObject');
                }
                
                // Update modal with detailed information
                if (detailsData && detailsData.artObject) {
                        const details = detailsData.artObject || {};
                        
                        // Ensure we have all the required fields
                        if (!details.plaqueDescriptionEnglish && !details.description && !details.physicalMedium && !details.location) {
                            console.warn('Missing critical artwork details, retrying fetch...');
                            // Retry the fetch once
                            const retryResponse = await fetchWithTimeout(`${API_ARTWORK_URL}/${artwork.objectNumber}`, {
                                method: 'GET'
                            }, 30000);
                            if (retryResponse.ok) {
                                const retryData = await retryResponse.json();
                                Object.assign(details, retryData.artObject || {});
                            }
                        }
                        
                        // Log the received details for debugging
                        console.log('Received artwork details:', details);
                        
                        // Update description - prioritize the English plaque description
                        modalDescription.innerHTML = ''; // Clear existing content
                        
                        // Get the description from the API response
                        let descriptionText = '';
                        
                        // Use English plaque description as the primary source
                        if (details.plaqueDescriptionEnglish && details.plaqueDescriptionEnglish.trim().length > 0) {
                            console.log('Using English plaque description');
                            descriptionText = details.plaqueDescriptionEnglish;
                        }
                        // Try label description next
                        else if (details.label?.description && details.label.description.trim().length > 0) {
                            console.log('Using label description');
                            descriptionText = details.label.description;
                        }
                        // Then try scLabelLine
                        else if (details.scLabelLine && details.scLabelLine.trim().length > 0) {
                            console.log('Using scLabelLine');
                            descriptionText = details.scLabelLine;
                        }
                        // Finally try regular description
                        else if (details.description && details.description.trim().length > 0) {
                            console.log('Using English description (fallback)');
                            descriptionText = details.description;
                        }

                        // Log all available descriptions
                        console.log('Available descriptions:', {
                            englishPlaque: details.plaqueDescriptionEnglish,
                            englishDescription: details.description,
                            dutchDescription: details.dutchDescription
                        });
                        
                        // If no description is available, try other fields
                        if (!descriptionText) {
                            if (details.label && details.label.description && details.label.description.trim().length > 0) {
                                descriptionText = details.label.description;
                            } else if (details.longTitle && details.longTitle.length > artwork.longTitle.length) {
                                descriptionText = details.longTitle;
                            } else {
                                descriptionText = artwork.longTitle;
                            }
                        }
                        
                        // Log the full API response and description sources for debugging
                        console.log('Full API response:', detailsData);
                        console.log('Description sources:', {
                            description: details.description,
                            plaqueDescriptionEnglish: details.plaqueDescriptionEnglish,
                            labelDescription: details.label?.description,
                            longTitle: details.longTitle
                        });

                        // Log the actual description text being used
                        console.log('Final description text:', descriptionText);
                        
                        // Format description into paragraphs
                        const paragraphs = descriptionText.split(/\n+/);
                        paragraphs.forEach(paragraph => {
                            if (paragraph.trim().length > 0) {
                                const p = document.createElement('p');
                                p.textContent = paragraph.trim();
                                modalDescription.appendChild(p);
                            }
                        });
                        
                        // TECHNICAL DETAILS SECTION
                        console.log('Setting technical details:', {
                            physicalMedium: details.physicalMedium,
                            materials: details.materials,
                            techniques: details.techniques,
                            subTitle: details.subTitle,
                            dimensions: details.dimensions,
                            dimensionParts: details.dimensionParts,
                            location: details.location,
                            currentLocation: details.currentLocation,
                            gallery: details.gallery
                        });
                        
                        // 1. Physical Medium - Combine all material information
                        const mediumParts = [
                            details.physicalMedium,
                            details.materials?.length ? details.materials.join(', ') : null,
                            details.techniques?.length ? details.techniques.join(', ') : null
                        ].filter(Boolean);
                        
                        materialsElement.innerHTML = mediumParts.length > 0 ?
                            `<strong>🎨 Medium:</strong> ${mediumParts.join(' - ')}` :
                            '<strong>🎨 Medium:</strong> Information not available';
                        
                        // 2. Size - Use dimensionParts or subTitle
                        const dimensionInfo = details.dimensionParts?.length ? 
                            details.dimensionParts.map(part => `${part.type}: ${part.value} ${part.unit}`).join(' • ') :
                            details.subTitle?.includes('cm') ? details.subTitle :
                            details.dimensions?.length ? 
                                details.dimensions
                                    .filter(dim => dim.value && dim.unit)
                                    .map(dim => `${dim.type ? `${dim.type}: ` : ''}${dim.value} ${dim.unit}`)
                                    .join(' • ') : '';
                        
                        dimensionsElement.innerHTML = dimensionInfo ?
                            `<strong>📏 Size:</strong> ${dimensionInfo}` :
                            '<strong>📏 Size:</strong> Information not available';
                        
                        // 3. Location - Try all location fields
                        const locationInfo = [
                            details.location,
                            details.currentLocation,
                            details.gallery
                        ].find(loc => loc?.trim());
                        
                        locationElement.innerHTML = locationInfo ?
                            `<strong>📍 Location:</strong> ${locationInfo}` :
                            '<strong>📍 Location:</strong> Information not available';
                        
                        // Extra details for technical information section
                        // Create a new element for acquisition information
                        if (details.acquisition && (details.acquisition.date || details.acquisition.method)) {
                            const acquisitionInfo = document.createElement('div');
                            acquisitionInfo.id = 'modal-acquisition';
                            acquisitionInfo.innerHTML = `<strong>🎁 Acquisition:</strong> ${details.acquisition.method || ''} ${details.acquisition.date || ''}`.trim();
                            technicalDetailsDiv.appendChild(acquisitionInfo);
                        }
                        
                        // Create a new element for inventory number
                        if (details.objectNumber) {
                            const inventoryInfo = document.createElement('div');
                            inventoryInfo.id = 'modal-inventory';
                            inventoryInfo.innerHTML = `<strong>📦 Inventory:</strong> ${details.objectNumber}`;
                            technicalDetailsDiv.appendChild(inventoryInfo);
                        }
                    }
            } catch (error) {
                console.error('Error fetching artwork details:', {
                    error: error.message,
                    stack: error.stack,
                    artwork: artwork.objectNumber
                });
                
                // Show error state in description
                modalDescription.innerHTML = '<p>Error loading artwork description. Please try again later.</p>';
                
                // Show error state in technical details
                technicalDetailsDiv.innerHTML = `
                    <div class="error-state">
                        <p><em>Some technical details are temporarily unavailable.</em></p>
                        <div id="modal-dimensions"><strong>Size:</strong> Information not available</div>
                        <div id="modal-materials"><strong>Medium:</strong> Information not available</div>
                        <div id="modal-location"><strong>Location:</strong> Information not available</div>
                    </div>
                `;
            } finally {
                // Remove loading spinner from technical details
                const loadingState = technicalDetailsDiv.querySelector('.loading-state');
                if (loadingState) {
                    loadingState.remove();
                }
            }
        }
    }
});
