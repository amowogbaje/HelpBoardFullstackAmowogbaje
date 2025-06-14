#!/bin/bash

# Fix login issue on droplet - 400 Invalid request data
# This happens when database schema is outdated

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

# Check if database is accessible
check_database() {
    log_step "Checking database accessibility..."
    
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "db.*Up"; then
        log_error "Database container not running. Starting it..."
        docker compose -f "$COMPOSE_FILE" up -d db
        sleep 10
    fi
    
    # Test database connection
    if docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user; then
        log_success "Database is accessible"
    else
        log_error "Cannot connect to database"
        exit 1
    fi
}

# Check current schema and fix it
fix_schema() {
    log_step "Fixing database schema..."
    
    # Create comprehensive schema fix
    cat > schema_fix.sql << 'EOF'
-- Check current schema and add missing columns
DO $$ 
DECLARE
    col_exists boolean;
BEGIN
    -- Check and add 'role' column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='agents' AND column_name='role'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        ALTER TABLE agents ADD COLUMN role VARCHAR(50) DEFAULT 'agent';
        RAISE NOTICE 'Added role column';
    END IF;
    
    -- Check and add 'is_active' column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='agents' AND column_name='is_active'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        ALTER TABLE agents ADD COLUMN is_active BOOLEAN DEFAULT true;
        RAISE NOTICE 'Added is_active column';
    END IF;
    
    -- Check and add 'department' column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='agents' AND column_name='department'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        ALTER TABLE agents ADD COLUMN department VARCHAR(100);
        RAISE NOTICE 'Added department column';
    END IF;
    
    -- Check and add 'phone' column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='agents' AND column_name='phone'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        ALTER TABLE agents ADD COLUMN phone VARCHAR(20);
        RAISE NOTICE 'Added phone column';
    END IF;
    
    -- Check and add 'password_changed_at' column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='agents' AND column_name='password_changed_at'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        ALTER TABLE agents ADD COLUMN password_changed_at TIMESTAMP;
        RAISE NOTICE 'Added password_changed_at column';
    END IF;
    
    -- Check and add 'last_login_at' column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='agents' AND column_name='last_login_at'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        ALTER TABLE agents ADD COLUMN last_login_at TIMESTAMP;
        RAISE NOTICE 'Added last_login_at column';
    END IF;
END $$;

-- Update existing agents with proper values
UPDATE agents SET 
    role = COALESCE(role, 'agent'),
    is_active = COALESCE(is_active, true),
    department = COALESCE(department, 'Customer Support'),
    password_changed_at = COALESCE(password_changed_at, created_at)
WHERE role IS NULL OR is_active IS NULL;

-- Ensure admin exists with proper credentials
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
    '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'System Administrator',
    'admin',
    true,
    true,
    'Administration',
    '+1-555-0100',
    NOW(),
    NOW(),
    NOW()
) ON CONFLICT (email) DO UPDATE SET
    password = EXCLUDED.password,
    role = EXCLUDED.role,
    is_active = EXCLUDED.is_active,
    department = EXCLUDED.department,
    phone = EXCLUDED.phone,
    updated_at = NOW();

-- Ensure agent exists with proper credentials  
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
    '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'Support Agent',
    'agent',
    true,
    true,
    'Customer Support',
    '+1-555-0200',
    NOW(),
    NOW(),
    NOW()
) ON CONFLICT (email) DO UPDATE SET
    password = EXCLUDED.password,
    role = EXCLUDED.role,
    is_active = EXCLUDED.is_active,
    department = EXCLUDED.department,
    phone = EXCLUDED.phone,
    updated_at = NOW();
EOF

    # Execute schema fix
    if docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard < schema_fix.sql; then
        log_success "Database schema updated successfully"
    else
        log_error "Failed to update database schema"
        exit 1
    fi
    
    rm schema_fix.sql
}

# Test the login API directly
test_login() {
    log_step "Testing login functionality..."
    
    # Wait for app to restart
    sleep 5
    
    # Test admin login
    local response=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}')
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    log_info "Admin login test - HTTP: $http_code"
    log_info "Response: $body"
    
    if [ "$http_code" = "200" ]; then
        log_success "Admin login working correctly"
    else
        log_error "Admin login still failing"
        return 1
    fi
    
    # Test agent login
    local response2=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"agent@helpboard.com","password":"password123"}')
    
    local http_code2="${response2: -3}"
    local body2="${response2%???}"
    
    log_info "Agent login test - HTTP: $http_code2"
    log_info "Response: $body2"
    
    if [ "$http_code2" = "200" ]; then
        log_success "Agent login working correctly"
    else
        log_error "Agent login still failing"
        return 1
    fi
}

# Restart application
restart_app() {
    log_step "Restarting application..."
    
    docker compose -f "$COMPOSE_FILE" restart app
    
    log_info "Waiting for application to restart..."
    sleep 15
}

# Main execution
main() {
    log_info "Fixing droplet login issue (400: Invalid request data)..."
    
    check_database
    fix_schema
    restart_app
    
    if test_login; then
        log_success "Login issue fixed successfully!"
        echo ""
        log_info "Working credentials:"
        echo "  Admin: admin@helpboard.com / admin123"
        echo "  Agent: agent@helpboard.com / password123"
        echo ""
        log_info "You can now login at your droplet domain"
    else
        log_error "Login issue persists. Check application logs:"
        echo "docker compose -f $COMPOSE_FILE logs app"
    fi
}

main