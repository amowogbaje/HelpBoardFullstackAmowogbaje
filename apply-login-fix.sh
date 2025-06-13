#!/bin/bash

# Apply login route fix to droplet
set -e

COMPOSE_FILE="docker-compose.dev.yml"

echo "Applying login fix..."

# Restart app to pick up code changes
docker compose -f "$COMPOSE_FILE" restart app

echo "Waiting for application to restart..."
sleep 15

# Test the fixed login endpoint
echo "Testing login..."
response=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@helpboard.com","password":"admin123"}')

http_code="${response: -3}"
body="${response%???}"

echo "HTTP Status: $http_code"
echo "Response: $body"

if [ "$http_code" = "200" ] && echo "$body" | grep -q "Login successful"; then
    echo ""
    echo "✅ SUCCESS: Login is now working!"
    echo ""
    echo "You can now access your application at your domain with:"
    echo "  Admin: admin@helpboard.com / admin123"
    echo "  Agent: agent@helpboard.com / password123"
else
    echo ""
    echo "❌ Login still failing. Checking application logs..."
    docker compose -f "$COMPOSE_FILE" logs --tail=20 app
fi