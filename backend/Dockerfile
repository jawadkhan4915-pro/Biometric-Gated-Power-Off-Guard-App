FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/

# Expose port
EXPOSE 5000

# Set environment variable defaults
ENV NODE_ENV=production
ENV PORT=5000

# Command to run the application
CMD ["npm", "start"]
