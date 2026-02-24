# Use official Node.js 18 LTS image as base
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy package files first (for layer caching)
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy all app source code
COPY . .

# Expose port 3000 (the port your app runs on)
EXPOSE 3000

# Command to run the app
CMD ["node", "server.js"]
