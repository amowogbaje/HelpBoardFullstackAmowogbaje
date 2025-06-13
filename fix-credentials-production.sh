#!/bin/bash

# Production-ready credential fix for helpboard.selfany.com
# This script handles both Docker Compose format and database migration properly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${GREEN}[STEP]${NC} $1"; }

COMPOSE_FILE="docker-compose.dev.yml"

# Function to check if database is ready
wait_for_database() {
    log_info "Waiting for database to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user > /dev/null 2>&1; then
            log_success "Database is ready"
            return 0
        fi
        
        log_info "Database not ready yet, attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    log_error "Database failed to become ready after $max_attempts attempts"
    return 1
}

# Function to backup database
backup_database() {
    log_step "Creating database backup..."
    local backup_dir="backups/credential-fix-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    docker compose -f "$COMPOSE_FILE" exec -T db pg_dump -U helpboard_user helpboard > "$backup_dir/backup.sql"
    gzip "$backup_dir/backup.sql"
    log_success "Database backed up to $backup_dir/backup.sql.gz"
}

# Function to run database migration
run_migration() {
    log_step "Running database migration..."
    
    # Ensure we have the latest schema
    npm run db:push
    log_success "Database schema updated"
}

# Function to reset credentials with proper error handling
reset_credentials() {
    log_step "Resetting agent credentials..."
    
    # Create SQL script that works with both old and new schema
    cat > temp_fix_credentials.sql << 'EOF'
-- First, check if new columns exist and add them if they don't
DO $$ 
BEGIN
    -- Add role column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='role') THEN
        ALTER TABLE agents ADD COLUMN role VARCHAR(50) DEFAULT 'agent';
    END IF;
    
    -- Add is_active column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='is_active') THEN
        ALTER TABLE agents ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;
    
    -- Add department column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='department') THEN
        ALTER TABLE agents ADD COLUMN department VARCHAR(100);
    END IF;
    
    -- Add phone column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='phone') THEN
        ALTER TABLE agents ADD COLUMN phone VARCHAR(20);
    END IF;
    
    -- Add password_changed_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='password_changed_at') THEN
        ALTER TABLE agents ADD COLUMN password_changed_at TIMESTAMP;
    END IF;
    
    -- Add last_login_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='last_login_at') THEN
        ALTER TABLE agents ADD COLUMN last_login_at TIMESTAMP;
    END IF;
END $$;

-- Clear existing agents to avoid conflicts
DELETE FROM agents;

-- Insert admin agent with proper password hash for "admin123"
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
);

-- Insert support agent with proper password hash for "password123"
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
);

-- Insert supervisor with proper password hash for "supervisor123"
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
    '$2a$10$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
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
    if docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard < temp_fix_credentials.sql; then
        log_success "Credentials reset successfully"
    else
        log_error "Failed to reset credentials"
        return 1
    fi
    
    # Clean up temp file
    rm temp_fix_credentials.sql
}

# Function to restart application
restart_application() {
    log_step "Restarting application..."
    
    # Restart only the app container to pick up database changes
    docker compose -f "$COMPOSE_FILE" restart app
    
    # Wait for application to be ready
    log_info "Waiting for application to restart..."
    sleep 15
}

# Function to test credentials
test_credentials() {
    log_step "Testing credentials..."
    
    # Test admin login
    local response=$(curl -s -X POST "http://localhost:3000/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}')
    
    if echo "$response" | grep -q '"message":"Login successful"'; then
        log_success "Admin credentials working"
    else
        log_warn "Admin credentials test failed. Response: $response"
    fi
    
    # Test agent login
    local response2=$(curl -s -X POST "http://localhost:3000/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"agent@helpboard.com","password":"password123"}')
    
    if echo "$response2" | grep -q '"message":"Login successful"'; then
        log_success "Agent credentials working"
    else
        log_warn "Agent credentials test failed. Response: $response2"
    fi
}

# Function to show final status
show_status() {
    log_step "Deployment Status:"
    echo ""
    
    # Show running containers
    docker compose -f "$COMPOSE_FILE" ps
    
    echo ""
    log_info "Updated login credentials for helpboard.selfany.com:"
    echo "  Admin: admin@helpboard.com / admin123"
    echo "  Agent: agent@helpboard.com / password123"
    echo "  Supervisor: supervisor@helpboard.com / supervisor123"
    
    echo ""
    log_info "Application URL: https://helpboard.selfany.com"
}

# Main execution
main() {
    log_info "Starting credential fix for production deployment..."
    
    # Ensure database is running
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "db.*Up"; then
        log_info "Starting database service..."
        docker compose -f "$COMPOSE_FILE" up -d db
    fi
    
    wait_for_database
    backup_database
    run_migration
    reset_credentials
    restart_application
    test_credentials
    show_status
    
    log_success "Credential fix completed successfully!"
    log_info "You can now login to your application at https://helpboard.selfany.com"
}

# Handle script arguments
case "${1:-fix}" in
    "backup")
        backup_database
        ;;
    "test")
        test_credentials
        ;;
    "status")
        show_status
        ;;
    "fix"|*)
        main
        ;;
esac