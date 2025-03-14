FROM node:18-alpine

# Create app directory
WORKDIR /app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
COPY package*.json ./
RUN npm install --production

# Bundle app source
COPY . .

# The app binds to port 3000 by default, 
# but can be configured via the PORT environment variable
EXPOSE 3000

# Start the application
CMD ["node", "server.js"]
