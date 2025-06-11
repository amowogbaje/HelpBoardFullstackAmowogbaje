#!/bin/bash

# Fix Docker networking issue

echo "Diagnosing network connectivity..."

# Check what's running
docker compose ps

# Check port bindings
docker compose port app 5000 || echo "Port binding failed"

# Check if app container is actually listening
docker compose exec app netstat -tlnp | grep 5000 || echo "App not listening on port 5000"

# Check container logs
echo "Container logs:"
docker compose logs app | tail -10

# Check if we can reach app from inside the container
echo "Testing internal connectivity..."
docker compose exec app wget -q -O- http://localhost:5000/api/health || echo "Internal health check failed"

# Fix: Restart app container
echo "Restarting app container..."
docker compose restart app

sleep 10

# Test again
if curl -s http://localhost:5000/api/health > /dev/null; then
    echo "SUCCESS: App is now accessible"
    curl -s http://localhost:5000/api/health
else
    echo "Still failing. Checking if app is bound to correct interface..."
    
    # Check if server.js is binding to 0.0.0.0
    if grep -q "app.listen(port, '0.0.0.0'" server.js; then
        echo "Server is correctly bound to 0.0.0.0"
    else
        echo "Fixing server binding..."
        sed -i "s/app.listen(port,/app.listen(port, '0.0.0.0',/" server.js
        docker compose build --no-cache app
        docker compose up -d app
        sleep 10
        curl -s http://localhost:5000/api/health
    fi
fi