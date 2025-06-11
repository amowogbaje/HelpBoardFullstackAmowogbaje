#!/bin/bash

# Complete HelpBoard Setup Script for DigitalOcean
# Run this script on your droplet: curl -sSL https://raw.githubusercontent.com/YOUR_REPO/main/setup-production.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Setting up HelpBoard on DigitalOcean...${NC}"

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    apt update && apt install -y docker-compose-plugin
fi

# Create project directory
mkdir -p /opt/helpboard
cd /opt/helpboard

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM node:18-alpine
RUN apk add --no-cache curl
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 helpboard
RUN chown -R helpboard:nodejs /app
USER helpboard
EXPOSE 5000
HEALTHCHECK CMD curl -f http://localhost:5000/api/health || exit 1
CMD ["npx", "tsx", "server/production.ts"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build: .
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
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

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - app

volumes:
  postgres_data:
EOF

# Create nginx.conf
cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:5000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /ws {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF

# Create environment file
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://helpboard:helpboard123@postgres:5432/helpboard
POSTGRES_DB=helpboard
POSTGRES_USER=helpboard
POSTGRES_PASSWORD=helpboard123
OPENAI_API_KEY=your_openai_api_key_here
EOF

echo -e "${GREEN}✅ Configuration files created${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Upload your project files to /opt/helpboard"
echo "2. Run: docker compose up -d"
echo "3. Test: curl http://localhost/api/health"
echo ""
echo -e "${YELLOW}Your server IP: $(curl -s ifconfig.me)${NC}"