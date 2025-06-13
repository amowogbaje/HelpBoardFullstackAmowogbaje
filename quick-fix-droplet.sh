#!/bin/bash

# Quick fix for droplet database initialization issue
# This creates the schema and credentials properly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

COMPOSE_FILE="docker-compose.dev.yml"

# Ensure services are running
log_info "Starting services..."
docker compose -f "$COMPOSE_FILE" up -d

# Wait for database
log_info "Waiting for database..."
sleep 20

# Create schema from app container
log_info "Creating database schema..."
docker compose -f "$COMPOSE_FILE" exec -T app npm run db:push

# Create agents directly in database
log_info "Setting up agents..."
docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard << 'EOF'
-- Clear any existing agents
TRUNCATE TABLE agents CASCADE;

-- Insert admin agent
INSERT INTO agents (
    email, password, name, role, is_active, is_available,
    department, phone, created_at, updated_at, password_changed_at
) VALUES (
    'admin@helpboard.com',
    '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'System Administrator', 'admin', true, true,
    'Administration', '+1-555-0100', NOW(), NOW(), NOW()
);

-- Insert support agent
INSERT INTO agents (
    email, password, name, role, is_active, is_available,
    department, phone, created_at, updated_at, password_changed_at
) VALUES (
    'agent@helpboard.com',
    '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'Support Agent', 'agent', true, true,
    'Customer Support', '+1-555-0200', NOW(), NOW(), NOW()
);
EOF

# Restart app to pick up changes
log_info "Restarting application..."
docker compose -f "$COMPOSE_FILE" restart app

# Wait and test
sleep 15
log_info "Testing login..."

response=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@helpboard.com","password":"admin123"}')

http_code="${response: -3}"

if [ "$http_code" = "200" ]; then
    log_success "Login working! Credentials:"
    echo "  Admin: admin@helpboard.com / admin123"
    echo "  Agent: agent@helpboard.com / password123"
else
    log_error "Login test failed with HTTP $http_code"
    echo "Response: ${response%???}"
fi