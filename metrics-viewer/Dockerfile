# Build stage
FROM node:20-slim AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application files
COPY . .

# Build the application
RUN npm run build

# Production stage with static server
FROM node:20-slim

WORKDIR /app

# Install serve globally
RUN npm install -g serve

# Copy built files from builder
COPY --from=builder /app/dist ./dist

# Expose port
EXPOSE 4173

# Start static file server
CMD ["serve", "-s", "dist", "-l", "4173", "-n"]
