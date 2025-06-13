#!/bin/bash

# Check current login status and database state
set -e

COMPOSE_FILE="docker-compose.dev.yml"

echo "=== Checking Database Tables ==="
docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -c "\dt"

echo ""
echo "=== Checking Agents in Database ==="
docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -c "SELECT id, email, name, role, is_active FROM agents;"

echo ""
echo "=== Testing Login API ==="
response=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@helpboard.com","password":"admin123"}')

http_code="${response: -3}"
body="${response%???}"

echo "HTTP Status: $http_code"
echo "Response: $body"

if [ "$http_code" = "200" ]; then
    echo ""
    echo "✅ SUCCESS: Login is working!"
    echo "Credentials:"
    echo "  Admin: admin@helpboard.com / admin123"
    echo "  Agent: agent@helpboard.com / password123"
else
    echo ""
    echo "❌ LOGIN FAILED"
    echo "Check application logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail=10 app
fi