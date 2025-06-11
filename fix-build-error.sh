#!/bin/bash

# Fix Docker build error and get HelpBoard running

echo "Fixing Docker build error..."

# Stop containers
docker compose down

# Create corrected package.json without build script
cat > package.json << 'EOF'
{
  "name": "helpboard",
  "version": "1.0.0",
  "description": "HelpBoard AI Customer Support Platform",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# Create simplified Dockerfile that doesn't run build
cat > Dockerfile << 'EOF'
FROM node:18-alpine

# Install wget for healthcheck
RUN apk add --no-cache wget

WORKDIR /app

# Copy package files
COPY package.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application files
COPY server.js ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S helpboard -u 1001

# Change ownership
RUN chown -R helpboard:nodejs /app

# Switch to non-root user
USER helpboard

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:5000/api/health || exit 1

# Start application
CMD ["node", "server.js"]
EOF

# Update docker-compose to use correct ports
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build: 
      context: .
      dockerfile: Dockerfile
    ports:
      - "5000:5000"
      - "8080:5000"
    environment:
      - NODE_ENV=production
      - PORT=5000
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  app_data:
EOF

# Build and start
echo "Building with corrected configuration..."
docker compose build --no-cache

echo "Starting containers..."
docker compose up -d

# Wait for startup
sleep 20

# Test
if curl -f -s http://localhost:5000/api/health > /dev/null; then
    echo "SUCCESS: HelpBoard is now running!"
    
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    echo ""
    echo "Access your HelpBoard at:"
    echo "- http://$SERVER_IP:5000"
    echo "- http://$SERVER_IP:8080"
    echo ""
    
    echo "Container status:"
    docker compose ps
    
    echo ""
    echo "Health check response:"
    curl -s http://localhost:5000/api/health | head -5
    
else
    echo "Still having issues. Checking logs:"
    docker compose logs app | tail -10
fi