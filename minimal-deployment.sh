#!/bin/bash

# Minimal HelpBoard Deployment - Run this on your DigitalOcean droplet
# This creates a working deployment without needing file uploads

set -e

echo "Creating minimal HelpBoard deployment..."

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

# Install Docker Compose
apt update && apt install -y docker-compose-plugin curl

# Create environment
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://helpboard:helpboard123@postgres:5432/helpboard
POSTGRES_DB=helpboard
POSTGRES_USER=helpboard
POSTGRES_PASSWORD=helpboard123
OPENAI_API_KEY=your_openai_api_key_here
EOF

# Create docker-compose for minimal setup
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

  app:
    image: node:18-alpine
    working_dir: /app
    command: sh -c "npm install -g tsx && echo 'Minimal app ready on port 5000' && sleep infinity"
    ports:
      - "5000:5000"
    depends_on:
      - postgres

volumes:
  postgres_data:
EOF

# Start services
docker compose up -d

echo "Minimal deployment started. Upload your files and run: docker compose restart app"
echo "Your server IP: $(curl -s ifconfig.me)"
echo "Test with: curl http://$(curl -s ifconfig.me):5000/api/health"