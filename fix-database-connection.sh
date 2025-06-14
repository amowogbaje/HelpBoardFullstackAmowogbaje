#!/bin/bash

# Fix database connection issues on droplet
# Handles hostname resolution and Docker network problems

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

# Check Docker and Docker Compose
check_docker() {
    log_step "Checking Docker setup..."
    
    if ! docker --version > /dev/null 2>&1; then
        log_error "Docker not installed or not running"
        return 1
    fi
    
    if ! docker compose version > /dev/null 2>&1; then
        log_error "Docker Compose not available"
        return 1
    fi
    
    log_success "Docker setup OK"
}

# Stop all containers and clean up
cleanup_containers() {
    log_step "Cleaning up existing containers..."
    
    # Stop all containers
    docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
    
    # Remove any orphaned containers
    docker container prune -f
    
    # Remove unused networks
    docker network prune -f
    
    log_success "Containers cleaned up"
}

# Check and fix environment variables
check_environment() {
    log_step "Checking environment configuration..."
    
    if [ ! -f ".env" ]; then
        log_error ".env file not found"
        return 1
    fi
    
    # Source environment variables
    source .env
    
    # Check critical variables
    if [ -z "$DATABASE_URL" ]; then
        log_error "DATABASE_URL not set in .env"
        return 1
    fi
    
    log_info "DATABASE_URL: $DATABASE_URL"
    log_success "Environment configuration OK"
}

# Start database container first
start_database() {
    log_step "Starting database container..."
    
    # Start only the database service
    docker compose -f "$COMPOSE_FILE" up -d db
    
    # Wait for database to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user > /dev/null 2>&1; then
            log_success "Database is ready"
            return 0
        fi
        
        log_info "Waiting for database... attempt $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    log_error "Database failed to start"
    return 1
}

# Test database connection from host
test_connection_from_host() {
    log_step "Testing database connection from host..."
    
    # Get database container IP
    local db_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker compose -f "$COMPOSE_FILE" ps -q db))
    
    if [ -n "$db_ip" ]; then
        log_info "Database container IP: $db_ip"
        
        # Test connection using container IP
        if docker run --rm postgres:15 psql -h "$db_ip" -U helpboard_user -d helpboard -c "SELECT 1;" > /dev/null 2>&1; then
            log_success "Direct IP connection works"
        else
            log_error "Direct IP connection failed"
        fi
    fi
}

# Fix Docker network issues
fix_docker_network() {
    log_step "Fixing Docker network configuration..."
    
    # Create a custom network if it doesn't exist
    if ! docker network ls | grep -q "helpboard_network"; then
        docker network create helpboard_network
        log_info "Created helpboard_network"
    fi
    
    # Restart containers with proper network
    docker compose -f "$COMPOSE_FILE" down
    docker compose -f "$COMPOSE_FILE" up -d
    
    log_success "Docker network fixed"
}

# Update DATABASE_URL to use container IP as fallback
update_database_url() {
    log_step "Updating DATABASE_URL configuration..."
    
    # Get database container IP
    local db_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker compose -f "$COMPOSE_FILE" ps -q db))
    
    if [ -n "$db_ip" ]; then
        # Backup original .env
        cp .env .env.backup
        
        # Update DATABASE_URL to use IP instead of hostname
        local new_url="postgresql://helpboard_user:\$DB_PASSWORD@$db_ip:5432/helpboard"
        sed -i "s|DATABASE_URL=.*|DATABASE_URL=$new_url|" .env
        
        log_info "Updated DATABASE_URL to use IP: $db_ip"
        log_success "Database URL updated"
    else
        log_error "Could not get database IP"
        return 1
    fi
}

# Test database migration
test_migration() {
    log_step "Testing database migration..."
    
    # Wait for database to be fully ready
    sleep 10
    
    if npm run db:push; then
        log_success "Database migration successful"
    else
        log_error "Database migration failed"
        
        # Try alternative connection method
        log_info "Trying alternative connection method..."
        update_database_url
        
        # Restart app container
        docker compose -f "$COMPOSE_FILE" restart app
        sleep 10
        
        if npm run db:push; then
            log_success "Migration successful with IP connection"
        else
            log_error "Migration still failing"
            return 1
        fi
    fi
}

# Verify application connectivity
verify_app() {
    log_step "Verifying application database connectivity..."
    
    # Start all services
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for app to start
    sleep 15
    
    # Check application logs for database errors
    if docker compose -f "$COMPOSE_FILE" logs app | grep -i "database\|connection" | tail -5; then
        log_info "Recent database-related logs shown above"
    fi
    
    # Test health endpoint
    if curl -s "http://localhost:3000/api/health" > /dev/null; then
        log_success "Application is responding"
    else
        log_error "Application health check failed"
    fi
}

# Show current status
show_status() {
    log_step "Current deployment status:"
    echo ""
    
    echo "=== Docker Containers ==="
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
    
    echo "=== Database Connection Test ==="
    if docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user; then
        echo "✓ Database is accessible"
    else
        echo "✗ Database connection failed"
    fi
    echo ""
    
    echo "=== Network Configuration ==="
    docker network ls | grep helpboard || echo "No helpboard networks found"
    echo ""
    
    echo "=== Environment ==="
    if [ -f ".env" ]; then
        grep "DATABASE_URL" .env | head -1
    else
        echo "No .env file found"
    fi
}

# Main execution
main() {
    log_info "Fixing database connection issues..."
    
    check_docker
    check_environment
    cleanup_containers
    start_database
    test_connection_from_host
    
    if test_migration; then
        log_success "Database connection fixed!"
    else
        log_info "Trying network fixes..."
        fix_docker_network
        start_database
        test_migration
    fi
    
    verify_app
    show_status
    
    log_success "Database connection troubleshooting completed!"
}

# Handle different modes
case "${1:-fix}" in
    "status")
        show_status
        ;;
    "clean")
        cleanup_containers
        ;;
    "network")
        fix_docker_network
        ;;
    "fix"|*)
        main
        ;;
esac