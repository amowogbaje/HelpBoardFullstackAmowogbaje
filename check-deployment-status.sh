#!/bin/bash

# Check deployment status and continue if needed

echo "Checking HelpBoard deployment status..."

# Check if Docker containers are running
if docker compose ps | grep -q "Up"; then
    echo "✅ Containers are running"
    docker compose ps
else
    echo "❌ Containers not running, attempting to start..."
    docker compose up -d
    sleep 10
fi

# Check application health
echo "Testing application health..."
if curl -f -s http://localhost:5000/api/health > /dev/null; then
    echo "✅ Application health check passed"
    
    # Get health details
    echo "Health check response:"
    curl -s http://localhost:5000/api/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:5000/api/health
    
    # Test other endpoints
    echo -e "\nTesting endpoints..."
    
    if curl -f -s http://localhost:5000/api/conversations > /dev/null; then
        echo "✅ Conversations API working"
    else
        echo "❌ Conversations API failed"
    fi
    
    if curl -f -s http://localhost:5000/ > /dev/null; then
        echo "✅ Main page accessible"
    else
        echo "❌ Main page failed"
    fi
    
else
    echo "❌ Application health check failed"
    echo "Checking logs..."
    docker compose logs app | tail -20
    
    echo "Attempting restart..."
    docker compose restart app
    sleep 15
    
    if curl -f -s http://localhost:5000/api/health > /dev/null; then
        echo "✅ Application recovered after restart"
    else
        echo "❌ Application still failing after restart"
        exit 1
    fi
fi

# Get server IP and show access URLs
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

echo ""
echo "🎉 HelpBoard Deployment Status: SUCCESS"
echo "================================"
echo "Main URL: http://$SERVER_IP:5000"
echo "Alt URL:  http://$SERVER_IP:8080"
echo "Health:   http://$SERVER_IP:5000/api/health"
echo ""
echo "Container status:"
docker compose ps
echo ""
echo "Resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"