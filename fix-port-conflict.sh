#!/bin/bash

# Fix port conflict on DigitalOcean droplet

echo "Checking port usage and fixing conflicts..."

# Stop existing containers
docker compose down 2>/dev/null || true

# Check what's using port 80
echo "Services using port 80:"
netstat -tulpn | grep :80 || ss -tulpn | grep :80

# Stop Apache if running (common on Ubuntu)
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true

# Stop nginx if running system-wide
systemctl stop nginx 2>/dev/null || true

# Kill any processes using port 80
fuser -k 80/tcp 2>/dev/null || true

# Update docker-compose to use different ports initially
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-helpboard}
      POSTGRES_USER: ${POSTGRES_USER:-helpboard}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-helpboard123}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-helpboard} -d ${POSTGRES_DB:-helpboard}"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build: .
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL:-postgresql://helpboard:helpboard123@postgres:5432/helpboard}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-your_openai_api_key_here}
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

echo "Updated docker-compose.yml to use ports 8080 and 8443"

# Deploy with new ports
docker compose build --no-cache
docker compose up -d postgres
sleep 15
docker compose up -d app
sleep 25
docker compose up -d nginx

echo "Deployment complete!"
echo "Testing endpoints..."

# Test direct app
if curl -f http://localhost:5000/api/health >/dev/null 2>&1; then
    echo "✅ Direct app access working: http://$(curl -s ifconfig.me):5000"
else
    echo "❌ Direct app access failed"
fi

# Test through nginx
if curl -f http://localhost:8080/api/health >/dev/null 2>&1; then
    echo "✅ Nginx proxy working: http://$(curl -s ifconfig.me):8080"
else
    echo "❌ Nginx proxy failed"
fi

echo ""
echo "Container status:"
docker compose ps

echo ""
echo "Your HelpBoard is now accessible at:"
echo "- Direct: http://$(curl -s ifconfig.me):5000"
echo "- Via nginx: http://$(curl -s ifconfig.me):8080"
echo ""
echo "To use standard ports (80/443), first remove conflicting services:"
echo "systemctl stop apache2 && systemctl disable apache2"