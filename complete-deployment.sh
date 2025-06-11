#!/bin/bash

# Complete the HelpBoard deployment manually

echo "Completing HelpBoard deployment..."

# Kill any hanging processes
pkill -f deployment-troubleshooter 2>/dev/null || true

# Install Docker if needed
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

if ! docker compose version &> /dev/null; then
    apt update && apt install -y docker-compose-plugin
fi

# Stop any existing containers
docker compose down 2>/dev/null || true

# Free up ports
fuser -k 80/tcp 443/tcp 2>/dev/null || true

# Build and start
echo "Building containers..."
docker compose build --no-cache

echo "Starting deployment..."
docker compose up -d

# Wait and test
sleep 15

# Test deployment
if curl -f -s http://localhost:5000/api/health > /dev/null; then
    echo "SUCCESS: HelpBoard deployed and running"
    
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    echo ""
    echo "Access URLs:"
    echo "- Main: http://$SERVER_IP:5000"
    echo "- Alt:  http://$SERVER_IP:8080"
    echo ""
    
    # Show container status
    docker compose ps
    
    # Test health check
    echo ""
    echo "Health check:"
    curl -s http://localhost:5000/api/health
    
else
    echo "FAILED: Checking logs..."
    docker compose logs app | tail -20
fi