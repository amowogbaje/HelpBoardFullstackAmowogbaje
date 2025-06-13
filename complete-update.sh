#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

# Configuration
COMPOSE_FILE="docker-compose.dev.yml"
BACKUP_DIR="backups/complete-update-$(date +%Y%m%d_%H%M%S)"

# Create backup
create_backup() {
    log_step "Creating backup..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup database if running
    if docker compose -f "$COMPOSE_FILE" ps | grep -q "db.*Up"; then
        log_info "Backing up database..."
        docker compose -f "$COMPOSE_FILE" exec -T db pg_dump -U helpboard_user helpboard > "$BACKUP_DIR/database.sql"
        gzip "$BACKUP_DIR/database.sql"
        log_success "Database backup created: $BACKUP_DIR/database.sql.gz"
    fi
    
    # Backup environment files
    if [ -f ".env" ]; then
        cp .env "$BACKUP_DIR/"
        log_info "Environment file backed up"
    fi
}

# Update code from Git
update_code() {
    log_step "Updating code from Git..."
    
    # Stash any local changes
    if git status --porcelain | grep -q .; then
        log_warn "Local changes detected, stashing..."
        git stash
    fi
    
    # Pull latest changes
    git pull origin main
    log_success "Code updated from Git"
}

# Fix Docker Compose commands in all scripts
fix_docker_compose_commands() {
    log_step "Fixing Docker Compose command format..."
    
    # List of files to fix
    local files=("update-deployment.sh" "deploy-dev.sh" "deploy.sh" "deploy-fixed.sh" "deploy-single-domain.sh")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            sed -i 's/docker-compose/docker compose/g' "$file"
            log_info "Fixed Docker Compose commands in $file"
        fi
    done
    
    log_success "All Docker Compose commands updated to new format"
}

# Install/update dependencies
update_dependencies() {
    log_step "Updating dependencies..."
    
    if [ -f "package-lock.json" ]; then
        npm ci
    else
        npm install
    fi
    
    log_success "Dependencies updated"
}

# Run database migration
migrate_database() {
    log_step "Running database migration..."
    
    # Ensure database is running
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "db.*Up"; then
        log_warn "Database not running, starting it..."
        docker compose -f "$COMPOSE_FILE" up -d db
        sleep 15
    fi
    
    # Run migration
    npm run db:push
    log_success "Database schema updated"
}

# Reset credentials with proper multi-agent setup
reset_credentials() {
    log_step "Setting up multi-agent system credentials..."
    
    # Create SQL script with proper password hashes
    cat > temp_credentials.sql << 'EOF'
-- Clear existing agents to avoid conflicts
DELETE FROM agents;

-- Insert admin agent (admin@helpboard.com / admin123)
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
    updated_at
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
    NOW()
);

-- Insert support agent (agent@helpboard.com / password123)
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
    updated_at
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
    NOW()
);

-- Insert supervisor (supervisor@helpboard.com / supervisor123)
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
    updated_at
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
    NOW()
);
EOF

    # Execute SQL script
    docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard < temp_credentials.sql
    rm temp_credentials.sql
    
    log_success "Multi-agent credentials configured"
}

# Restart services
restart_services() {
    log_step "Restarting services..."
    
    # Stop all services
    docker compose -f "$COMPOSE_FILE" down
    
    # Start services
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 30
    
    log_success "Services restarted"
}

# Health check
health_check() {
    log_step "Performing health check..."
    
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "http://localhost:3000/api/health" > /dev/null; then
            log_success "Application is healthy and responding"
            return 0
        else
            log_warn "Health check failed, attempt $attempt/$max_attempts"
            if [ $attempt -eq $max_attempts ]; then
                log_error "Health check failed after $max_attempts attempts"
                log_info "Checking application logs..."
                docker compose -f "$COMPOSE_FILE" logs --tail=20 app
                return 1
            fi
            sleep 10
            ((attempt++))
        fi
    done
}

# Show status
show_status() {
    log_step "Current deployment status:"
    
    echo ""
    docker compose -f "$COMPOSE_FILE" ps
    
    echo ""
    log_info "Available login credentials:"
    echo "  Admin: admin@helpboard.com / admin123"
    echo "  Agent: agent@helpboard.com / password123"
    echo "  Supervisor: supervisor@helpboard.com / supervisor123"
    
    echo ""
    log_info "Application URL: https://helpboard.selfany.com"
}

# Main execution
main() {
    log_info "Starting complete update process..."
    
    create_backup
    update_code
    fix_docker_compose_commands
    update_dependencies
    migrate_database
    reset_credentials
    restart_services
    
    if health_check; then
        show_status
        log_success "Complete update finished successfully!"
    else
        log_error "Update completed but health check failed"
        log_info "Check the logs and try restarting: docker compose -f $COMPOSE_FILE restart"
        exit 1
    fi
}

# Handle script arguments
case "${1:-update}" in
    "backup")
        create_backup
        ;;
    "health")
        health_check
        ;;
    "status")
        show_status
        ;;
    "credentials")
        migrate_database
        reset_credentials
        restart_services
        health_check
        show_status
        ;;
    "update"|*)
        main
        ;;
esac