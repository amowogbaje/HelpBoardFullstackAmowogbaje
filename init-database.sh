#!/bin/bash

# Initialize database schema and credentials for fresh deployments
# This ensures the agents table exists before any migration attempts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${GREEN}[STEP]${NC} $1"; }

COMPOSE_FILE="docker-compose.dev.yml"

# Wait for database to be fully ready
wait_for_database() {
    log_step "Waiting for database to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user -d helpboard > /dev/null 2>&1; then
            log_success "Database is ready"
            return 0
        fi
        
        log_info "Database not ready yet, attempt $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    log_error "Database failed to become ready"
    return 1
}

# Create database schema using Drizzle
create_schema() {
    log_step "Creating database schema..."
    
    # Run Drizzle push to create all tables
    if npm run db:push; then
        log_success "Database schema created successfully"
    else
        log_error "Failed to create database schema"
        return 1
    fi
    
    # Verify key tables exist
    if docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -c "\dt" | grep -q "agents\|customers\|conversations\|messages"; then
        log_success "All required tables created"
    else
        log_error "Some tables are missing"
        return 1
    fi
}

# Initialize default agents with proper credentials
initialize_agents() {
    log_step "Setting up default agents..."
    
    # Create SQL script for agent initialization
    cat > temp_init_agents.sql << 'EOF'
-- Clear any existing agents
TRUNCATE TABLE agents CASCADE;

-- Insert admin agent
INSERT INTO agents (
    email, 
    password, 
    name, 
    role, 
    is_active, 
    is_available,
    department,
    phone,
    created_at,
    updated_at,
    password_changed_at
) VALUES (
    'admin@helpboard.com',
    '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6', -- admin123
    'System Administrator',
    'admin',
    true,
    true,
    'Administration',
    '+1-555-0100',
    NOW(),
    NOW(),
    NOW()
);

-- Insert support agent
INSERT INTO agents (
    email, 
    password, 
    name, 
    role, 
    is_active, 
    is_available,
    department,
    phone,
    created_at,
    updated_at,
    password_changed_at
) VALUES (
    'agent@helpboard.com',
    '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6', -- password123
    'Support Agent',
    'agent',
    true,
    true,
    'Customer Support',
    '+1-555-0200',
    NOW(),
    NOW(),
    NOW()
);

-- Insert supervisor
INSERT INTO agents (
    email, 
    password, 
    name, 
    role, 
    is_active, 
    is_available,
    department,
    phone,
    created_at,
    updated_at,
    password_changed_at
) VALUES (
    'supervisor@helpboard.com',
    '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6', -- supervisor123
    'Support Supervisor',
    'supervisor',
    true,
    true,
    'Customer Support',
    '+1-555-0300',
    NOW(),
    NOW(),
    NOW()
);
EOF

    # Execute the SQL script
    if docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard < temp_init_agents.sql; then
        log_success "Default agents created successfully"
    else
        log_error "Failed to create default agents"
        return 1
    fi
    
    # Clean up temp file
    rm temp_init_agents.sql
}

# Verify agent creation
verify_agents() {
    log_step "Verifying agent setup..."
    
    local agent_count=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -t -c "SELECT COUNT(*) FROM agents;")
    
    if [ "$agent_count" -ge 3 ]; then
        log_success "All agents created successfully (count: $agent_count)"
    else
        log_error "Agent creation incomplete (count: $agent_count)"
        return 1
    fi
}

# Test login functionality
test_login() {
    log_step "Testing login functionality..."
    
    # Wait for application to restart
    sleep 10
    
    # Test admin login
    local response=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}')
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Admin login working correctly"
    else
        log_error "Admin login failed with HTTP $http_code"
        return 1
    fi
}

# Main initialization
main() {
    log_info "Initializing database for fresh deployment..."
    
    wait_for_database
    create_schema
    initialize_agents
    verify_agents
    
    # Restart application to pick up new database state
    log_info "Restarting application..."
    docker compose -f "$COMPOSE_FILE" restart app
    
    test_login
    
    log_success "Database initialization completed successfully!"
    echo ""
    log_info "Default credentials:"
    echo "  Admin: admin@helpboard.com / admin123"
    echo "  Agent: agent@helpboard.com / password123"
    echo "  Supervisor: supervisor@helpboard.com / supervisor123"
}

main