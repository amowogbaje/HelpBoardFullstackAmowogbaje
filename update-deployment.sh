#!/bin/bash

# HelpBoard Update Deployment Script
# Handles Git updates, database migrations, and service restarts

set -e

DOMAIN="helpboard.selfany.com"
COMPOSE_FILE="docker-compose.dev.yml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Create backup before update
create_backup() {
    log_step "Creating backup before update..."
    
    local backup_dir="backups/pre-update-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup database
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "db.*Up"; then
        log_info "Backing up database..."
        docker-compose -f "$COMPOSE_FILE" exec -T db pg_dump -U helpboard_user helpboard > "$backup_dir/database.sql"
        gzip "$backup_dir/database.sql"
        log_info "Database backup created: $backup_dir/database.sql.gz"
    fi
    
    # Backup environment file
    if [ -f ".env" ]; then
        cp .env "$backup_dir/env.backup"
        log_info "Environment file backed up"
    fi
    
    log_info "Backup completed in $backup_dir"
}

# Pull latest changes from Git
update_code() {
    log_step "Updating code from Git repository..."
    
    # Stash any local changes
    if git status --porcelain | grep -q .; then
        log_warn "Local changes detected, stashing them..."
        git stash push -m "Auto-stash before update $(date)"
    fi
    
    # Pull latest changes
    git fetch origin
    git pull origin main
    
    log_info "Code updated successfully"
}

# Run database migrations
migrate_database() {
    log_step "Running database migrations..."
    
    # Check if database service is running
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "db.*Up"; then
        log_warn "Database service not running, starting it..."
        docker-compose -f "$COMPOSE_FILE" up -d db
        sleep 10
    fi
    
    # Run Drizzle push to update schema
    log_info "Updating database schema..."
    npm run db:push
    
    log_info "Database migrations completed"
}

# Update dependencies
update_dependencies() {
    log_step "Updating dependencies..."
    
    # Check if package.json or package-lock.json changed
    if git diff HEAD~1 --name-only | grep -q "package"; then
        log_info "Package files changed, updating dependencies..."
        npm ci
        log_info "Dependencies updated"
    else
        log_info "No dependency changes detected"
    fi
}

# Restart services
restart_services() {
    log_step "Restarting services..."
    
    # Restart application container to pick up changes
    docker-compose -f "$COMPOSE_FILE" restart app
    
    # Wait for services to be healthy
    log_info "Waiting for services to restart..."
    sleep 15
    
    # Check health
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -k -s "https://$DOMAIN/api/health" | grep -q "ok\|healthy"; then
            log_info "Services restarted successfully"
            return 0
        fi
        
        log_info "Health check attempt $attempt/$max_attempts..."
        sleep 5
        ((attempt++))
    done
    
    log_warn "Services may not be fully healthy, check logs if needed"
}

# Show current status
show_status() {
    log_step "Current deployment status..."
    
    echo
    echo "=== Git Status ==="
    git log --oneline -5
    echo
    
    echo "=== Service Status ==="
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    
    echo "=== Health Check ==="
    if curl -k -s "https://$DOMAIN/api/health" | grep -q "ok\|healthy"; then
        echo "✅ Application is healthy"
    else
        echo "❌ Application health check failed"
    fi
    echo
    
    echo "=== Default Credentials ==="
    echo "Admin Login:"
    echo "  Email: admin@helpboard.com"
    echo "  Password: admin123"
    echo
    echo "Agent Login:"
    echo "  Email: agent@helpboard.com"
    echo "  Password: password123"
    echo
}

# Rollback function
rollback_deployment() {
    log_step "Rolling back to previous version..."
    
    # Find the most recent backup
    local latest_backup=$(ls -1t backups/pre-update-* 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        log_error "No backup found for rollback"
        return 1
    fi
    
    log_info "Rolling back using backup: $latest_backup"
    
    # Rollback Git changes
    git reset --hard HEAD~1
    
    # Restore database if backup exists
    if [ -f "$latest_backup/database.sql.gz" ]; then
        log_info "Restoring database..."
        gunzip -c "$latest_backup/database.sql.gz" | docker-compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user helpboard
    fi
    
    # Restart services
    restart_services
    
    log_info "Rollback completed"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    if [ ! -f ".env" ]; then
        log_error ".env file not found. Please create it with required configuration."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker-compose --version &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Use docker compose if available, fallback to docker-compose
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
    
    log_info "Prerequisites check passed"
}

# Full update process
full_update() {
    log_info "Starting full HelpBoard update process..."
    
    check_prerequisites
    create_backup
    update_code
    update_dependencies
    migrate_database
    restart_services
    show_status
    
    log_info "Update completed successfully!"
    log_info "Your HelpBoard instance is now running the latest version"
}

# Quick update (no backup)
quick_update() {
    log_info "Starting quick update (no backup)..."
    
    check_prerequisites
    update_code
    restart_services
    
    log_info "Quick update completed!"
}

# Show usage
show_usage() {
    cat << EOF
HelpBoard Update Deployment Script

Usage: $0 [COMMAND]

Commands:
    update          Full update with backup (recommended)
    quick           Quick update without backup  
    rollback        Rollback to previous version
    migrate         Run database migrations only
    status          Show current deployment status
    backup          Create backup only
    restart         Restart services only
    help            Show this help

Examples:
    $0 update       # Full update with backup
    $0 quick        # Quick code update only
    $0 rollback     # Rollback if issues occur
    $0 status       # Check current status

Default Credentials after update:
    Admin: admin@helpboard.com / admin123
    Agent: agent@helpboard.com / password123

EOF
}

# Main execution
case "$1" in
    "update"|"")
        full_update
        ;;
    "quick")
        quick_update
        ;;
    "rollback")
        rollback_deployment
        ;;
    "migrate")
        check_prerequisites
        migrate_database
        ;;
    "status")
        show_status
        ;;
    "backup")
        create_backup
        ;;
    "restart")
        check_prerequisites
        restart_services
        ;;
    "help")
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac