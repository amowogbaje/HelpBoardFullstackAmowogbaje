#!/bin/bash

# Verify the HelpBoard deployment status

echo "Verifying HelpBoard deployment..."

# Check container status
echo "Container Status:"
docker compose ps

# Check if app is responding
echo -e "\nTesting Health Endpoint:"
if curl -f -s http://localhost:5000/api/health > /dev/null; then
    echo "✅ Health check passed"
    echo "Response:"
    curl -s http://localhost:5000/api/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:5000/api/health
else
    echo "❌ Health check failed"
    echo "Checking container logs:"
    docker compose logs app | tail -10
fi

# Test other endpoints
echo -e "\nTesting API Endpoints:"
for endpoint in "/api/conversations" "/"; do
    if curl -f -s "http://localhost:5000$endpoint" > /dev/null; then
        echo "✅ $endpoint working"
    else
        echo "❌ $endpoint failed"
    fi
done

# Check port bindings
echo -e "\nPort Bindings:"
docker compose port app 5000 2>/dev/null || echo "Port binding check failed"

# Get server IP and show access URLs
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")

echo -e "\n🎉 Deployment Status Summary:"
echo "================================"
echo "Server IP: $SERVER_IP"
echo "Main URL: http://$SERVER_IP:5000"
echo "Alt URL:  http://$SERVER_IP:8080"
echo "Health:   http://$SERVER_IP:5000/api/health"

# Check if accessible from external
echo -e "\nTesting external accessibility..."
if timeout 5 curl -f -s http://$SERVER_IP:5000/api/health > /dev/null 2>&1; then
    echo "✅ Externally accessible"
else
    echo "⚠️ May not be externally accessible (firewall/security groups)"
fi

echo -e "\nDeployment verification complete."