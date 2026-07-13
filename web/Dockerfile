FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application code
COPY . .

# Expose Next.js default port
EXPOSE 3000

# Start Next.js in development mode
CMD ["npm", "run", "dev"]
