#!/bin/bash

echo "Identifying and fixing all port conflicts..."

# Stop Docker containers first
docker compose down 2>/dev/null || true

# Check what's using ports 80 and 443
echo "=== Port 80 usage ==="
netstat -tlnp | grep :80 || ss -tlnp | grep :80 || echo "Port 80 is free"

echo "=== Port 443 usage ==="
netstat -tlnp | grep :443 || ss -tlnp | grep :443 || echo "Port 443 is free"

# Kill processes using these ports
echo "Freeing ports 80 and 443..."
fuser -k 80/tcp 2>/dev/null || true
fuser -k 443/tcp 2>/dev/null || true

# Check for nginx running on host
if pgrep nginx > /dev/null; then
    echo "Stopping host nginx..."
    systemctl stop nginx 2>/dev/null || pkill nginx
fi

# Create docker-compose with alternative ports
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: helpboard
      POSTGRES_USER: helpboard
      POSTGRES_PASSWORD: helpboard123
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U helpboard -d helpboard"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build: .
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://helpboard:helpboard123@postgres:5432/helpboard
      - OPENAI_API_KEY=your_openai_api_key_here
      - PORT=5000
    ports:
      - "5000:5000"
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
      - "8443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
EOF

echo "Starting deployment with ports 8080 and 8443..."

# Deploy step by step
docker compose up -d postgres
echo "Waiting for database..."
sleep 20

docker compose up -d app
echo "Waiting for application..."
sleep 30

docker compose up -d nginx
echo "Starting nginx proxy..."
sleep 10

# Test deployment
echo "Testing deployment..."
if curl -f -s http://localhost:5000/api/health > /dev/null; then
    echo "✅ App running on port 5000"
else
    echo "❌ App failed on port 5000"
    docker compose logs app | tail -10
fi

if curl -f -s http://localhost:8080/api/health > /dev/null; then
    echo "✅ Nginx proxy working on port 8080"
else
    echo "❌ Nginx proxy failed"
    docker compose logs nginx | tail -10
fi

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

echo ""
echo "🎉 Deployment Summary:"
echo "Direct access: http://$SERVER_IP:5000"
echo "Nginx proxy: http://$SERVER_IP:8080"
echo "Health check: http://$SERVER_IP:5000/api/health"
echo ""
echo "Container status:"
docker compose ps