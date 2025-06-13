#!/bin/bash

# Debug the exact login issue on droplet
set -e

COMPOSE_FILE="docker-compose.dev.yml"

echo "=== Debugging Login Issue ==="

# Check application logs for recent errors
echo "Recent application logs:"
docker compose -f "$COMPOSE_FILE" logs --tail=20 app

echo ""
echo "=== Testing Raw Login Request ==="

# Test with verbose curl to see exact request/response
curl -v -X POST "http://localhost:3000/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@helpboard.com","password":"admin123"}' 2>&1

echo ""
echo ""
echo "=== Checking Database Agent ==="
docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -c "SELECT email, name, role, length(password) as pwd_len FROM agents WHERE email='admin@helpboard.com';"

echo ""
echo "=== Testing Password Verification ==="
# Create a simple Node.js script to test password verification
cat > test_password.js << 'EOF'
const bcrypt = require('bcryptjs');

async function testPassword() {
    const plainPassword = 'admin123';
    const hashedFromDB = '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6';
    
    console.log('Testing password verification...');
    console.log('Plain password:', plainPassword);
    console.log('Hash from DB:', hashedFromDB);
    
    const isValid = await bcrypt.compare(plainPassword, hashedFromDB);
    console.log('Password valid:', isValid);
    
    // Test if password is actually password123
    const isPassword123 = await bcrypt.compare('password123', hashedFromDB);
    console.log('Is password123:', isPassword123);
}

testPassword().catch(console.error);
EOF

docker compose -f "$COMPOSE_FILE" exec -T app node -e "$(cat test_password.js)"
rm test_password.js

echo ""
echo "=== Checking Login Route Registration ==="
echo "Available routes:"
docker compose -f "$COMPOSE_FILE" logs app | grep -i "route\|login\|endpoint" | tail -5