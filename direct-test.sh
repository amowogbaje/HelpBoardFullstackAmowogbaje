#!/bin/bash

# Direct test and diagnosis

echo "Running direct container diagnosis..."

# Check if containers are actually running
docker ps | grep helpboard

# Get the app container ID
APP_CONTAINER=$(docker ps --filter "name=helpboard-app" --format "{{.ID}}" | head -1)

if [ -n "$APP_CONTAINER" ]; then
    echo "App container found: $APP_CONTAINER"
    
    # Test internal connectivity
    echo "Testing inside container:"
    docker exec $APP_CONTAINER wget -q -O- http://localhost:5000/api/health 2>/dev/null || echo "Internal test failed"
    
    # Check what the app is actually listening on
    echo "Network status inside container:"
    docker exec $APP_CONTAINER netstat -tlnp 2>/dev/null || docker exec $APP_CONTAINER ss -tlnp
    
    # Check container logs
    echo "Recent logs:"
    docker logs $APP_CONTAINER | tail -5
    
    # Get container IP
    CONTAINER_IP=$(docker inspect $APP_CONTAINER --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
    echo "Container IP: $CONTAINER_IP"
    
    # Test direct container access
    if [ -n "$CONTAINER_IP" ]; then
        curl -s http://$CONTAINER_IP:5000/api/health || echo "Direct container access failed"
    fi
else
    echo "No app container found"
    docker ps
fi

# Check port mappings
echo "Port mappings:"
docker port $(docker ps --filter "name=helpboard-app" --format "{{.ID}}" | head -1) 2>/dev/null || echo "No port mappings found"

# Try accessing via nginx proxy (port 8080)
echo "Testing nginx proxy:"
curl -s http://localhost:8080/api/health || echo "Nginx proxy failed"