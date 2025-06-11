#!/bin/bash

# Quick Fix for Vite Dependency Issue
# This script creates a working deployment without complex TypeScript compilation

set -e

echo "🔧 Applying quick fix for Vite dependency issue..."

# Stop containers
docker-compose down --remove-orphans 2>/dev/null || true

# Create a simple production Dockerfile
cat > Dockerfile.simple << 'EOF'
FROM node:18-alpine

RUN apk add --no-cache curl

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 helpboard

RUN chown -R helpboard:nodejs /app
USER helpboard

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

CMD ["npm", "run", "start:prod"]
EOF

# Add production start script to package.json
node -e "
const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
pkg.scripts['start:prod'] = 'NODE_ENV=production tsx server/production.ts';
require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"

# Update docker-compose to use simple Dockerfile
sed -i 's/build: \./build:\n      context: .\n      dockerfile: Dockerfile.simple/' docker-compose.yml

echo "✅ Quick fix applied. Starting deployment..."

# Build and start
docker-compose build --no-cache app
docker-compose up -d postgres

# Wait for postgres
sleep 15

docker-compose up -d app

# Wait for app
sleep 30

docker-compose up -d nginx

# Test
sleep 10
echo "🧪 Testing deployment..."

if curl -f -s -k https://localhost/api/health >/dev/null 2>&1; then
    echo "✅ Deployment successful!"
    echo "🌐 Application is running at https://$(curl -s ifconfig.me)"
    echo "📊 Health check: https://$(curl -s ifconfig.me)/api/health"
else
    echo "❌ Still having issues. Check logs:"
    docker-compose logs app | tail -20
fi

echo "📋 Container status:"
docker-compose ps