#!/bin/bash

# Quick fix for the build error

echo "Fixing build issue..."

# Stop containers
docker compose down

# Remove the problematic build step from Dockerfile
cat > Dockerfile << 'EOF'
FROM node:18-alpine

RUN apk add --no-cache wget curl

WORKDIR /app

COPY package.json ./
RUN npm install

COPY server.js ./

RUN addgroup -g 1001 -S nodejs && adduser -S helpboard -u 1001
RUN chown -R helpboard:nodejs /app
USER helpboard

EXPOSE 5000

CMD ["node", "server.js"]
EOF

# Ensure package.json has no build script
cat > package.json << 'EOF'
{
  "name": "helpboard",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Rebuild and start
docker compose build --no-cache
docker compose up -d

sleep 15

# Test
curl -s http://localhost:5000/api/health || echo "Health check failed, checking logs..."
docker compose logs app | tail -10