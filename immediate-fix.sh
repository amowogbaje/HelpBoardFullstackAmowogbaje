#!/bin/bash

# Immediate fix for network binding issue

echo "Fixing network binding..."

# Check current server.js binding
if ! grep -q "0.0.0.0" server.js; then
    echo "Server not bound to 0.0.0.0 - fixing..."
    
    # Fix server.js to bind to all interfaces
    sed -i 's/app\.listen(port,/app.listen(port, "0.0.0.0",/' server.js
    
    # Rebuild and restart
    docker compose build --no-cache app
    docker compose up -d app
    
    sleep 15
fi

# Alternative: try direct container access
CONTAINER_IP=$(docker inspect helpboard-app-1 --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)

if [ -n "$CONTAINER_IP" ]; then
    echo "Testing direct container access at $CONTAINER_IP:5000"
    curl -s http://$CONTAINER_IP:5000/api/health || echo "Direct access failed"
fi

# Check if port is actually bound
netstat -tulpn | grep :5000 || echo "Port 5000 not bound on host"

# Final test
if curl -s http://localhost:5000/api/health > /dev/null; then
    echo "SUCCESS"
    SERVER_IP=$(curl -s ifconfig.me)
    echo "Access at: http://$SERVER_IP:5000"
else
    echo "Creating emergency standalone server..."
    
    # Kill containers and run direct Node.js
    docker compose down
    
    # Install Node.js if needed
    if ! command -v node > /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    # Run server directly
    nohup node server.js > server.log 2>&1 &
    sleep 5
    
    curl -s http://localhost:5000/api/health && echo "Direct Node.js server working"
fi