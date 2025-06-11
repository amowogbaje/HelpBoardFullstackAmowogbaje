#!/bin/bash

# HelpBoard Production Deployment Script
# Usage: ./deploy.sh [init|update|ssl|backup|rollback]

set -e

# Configuration
COMPOSE_FILE="docker-compose.prod.yml"
BACKUP_DIR="./backups"
ENV_FILE=".env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required files exist
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "docker-compose.prod.yml not found"
        exit 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error ".env file not found. Copy .env.example to .env and configure it."
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Load environment variables
load_env() {
    if [ -f "$ENV_FILE" ]; then
        export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
    fi
}

# Check if required environment variables are set
check_env_vars() {
    log_info "Checking environment variables..."
    
    required_vars=("DB_PASSWORD" "OPENAI_API_KEY" "SESSION_SECRET")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    log_info "Environment variables check passed"
}

# Build and deploy application
deploy_app() {
    log_info "Building and deploying HelpBoard..."
    
    # Pull latest images
    docker-compose -f "$COMPOSE_FILE" pull
    
    # Build application
    docker-compose -f "$COMPOSE_FILE" build app
    
    # Start services
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be healthy..."
    sleep 30
    
    # Check health
    check_health
}

# Update existing deployment
update_app() {
    log_info "Updating HelpBoard deployment..."
    
    # Create backup before update
    backup_database
    
    # Pull latest images
    docker-compose -f "$COMPOSE_FILE" pull
    
    # Rebuild app container
    docker-compose -f "$COMPOSE_FILE" build app
    
    # Rolling update - update app first
    docker-compose -f "$COMPOSE_FILE" up -d --no-deps app
    
    # Wait and check health
    sleep 15
    check_health
    
    # Update nginx if needed
    docker-compose -f "$COMPOSE_FILE" up -d --no-deps nginx
    
    log_info "Update completed successfully"
}

# Setup SSL certificates
setup_ssl() {
    log_info "Setting up SSL certificates..."
    
    # Create SSL directory
    mkdir -p ssl
    
    # Check if certificates already exist
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        log_warn "SSL certificates already exist. Use 'renew-ssl' to update them."
        return
    fi
    
    # Generate certificates with certbot
    docker-compose -f "$COMPOSE_FILE" --profile ssl-setup up certbot
    
    # Copy certificates
    if [ -d "certbot/conf/live/helpboard.selfany.com" ]; then
        cp certbot/conf/live/helpboard.selfany.com/fullchain.pem ssl/
        cp certbot/conf/live/helpboard.selfany.com/privkey.pem ssl/
        chmod 600 ssl/privkey.pem
        log_info "SSL certificates installed successfully"
    else
        log_error "Failed to generate SSL certificates"
        exit 1
    fi
}

# Renew SSL certificates
renew_ssl() {
    log_info "Renewing SSL certificates..."
    
    # Renew certificates
    docker-compose -f "$COMPOSE_FILE" run --rm certbot renew
    
    if [ $? -eq 0 ]; then
        # Copy renewed certificates
        cp certbot/conf/live/helpboard.selfany.com/fullchain.pem ssl/
        cp certbot/conf/live/helpboard.selfany.com/privkey.pem ssl/
        chmod 600 ssl/privkey.pem
        
        # Restart nginx to use new certificates
        docker-compose -f "$COMPOSE_FILE" restart nginx
        
        log_info "SSL certificates renewed successfully"
    else
        log_error "Failed to renew SSL certificates"
        exit 1
    fi
}

# Backup database
backup_database() {
    log_info "Creating database backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="$BACKUP_DIR/helpboard_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    # Create backup
    docker-compose -f "$COMPOSE_FILE" exec -T db pg_dump -U helpboard_user helpboard > "$BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        gzip "$BACKUP_FILE"
        log_info "Database backup created: ${BACKUP_FILE}.gz"
        
        # Clean old backups (keep last 7 days)
        find "$BACKUP_DIR" -name "helpboard_backup_*.sql.gz" -mtime +7 -delete
    else
        log_error "Failed to create database backup"
        exit 1
    fi
}

# Restore database from backup
restore_database() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        log_error "Usage: $0 restore <backup_file>"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_warn "This will overwrite the current database. Are you sure? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Database restore cancelled"
        exit 0
    fi
    
    log_info "Restoring database from $backup_file..."
    
    # Stop application to prevent connections
    docker-compose -f "$COMPOSE_FILE" stop app
    
    # Restore database
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" | docker-compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user helpboard
    else
        docker-compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user helpboard < "$backup_file"
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Database restored successfully"
        # Restart application
        docker-compose -f "$COMPOSE_FILE" start app
    else
        log_error "Failed to restore database"
        exit 1
    fi
}

# Check service health
check_health() {
    log_info "Checking service health..."
    
    # Wait for app to be ready
    max_attempts=30
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://localhost:5000/api/health > /dev/null 2>&1; then
            log_info "Application is healthy"
            return 0
        fi
        
        log_info "Waiting for application to be ready (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Application health check failed"
    docker-compose -f "$COMPOSE_FILE" logs app
    exit 1
}

# Show logs
show_logs() {
    local service="$1"
    
    if [ -z "$service" ]; then
        docker-compose -f "$COMPOSE_FILE" logs -f
    else
        docker-compose -f "$COMPOSE_FILE" logs -f "$service"
    fi
}

# Stop all services
stop_services() {
    log_info "Stopping all services..."
    docker-compose -f "$COMPOSE_FILE" down
}

# Rollback to previous deployment
rollback() {
    log_info "Rolling back to previous deployment..."
    
    # Find latest backup
    latest_backup=$(ls -t "$BACKUP_DIR"/helpboard_backup_*.sql.gz 2>/dev/null | head -n1)
    
    if [ -z "$latest_backup" ]; then
        log_error "No backup found for rollback"
        exit 1
    fi
    
    log_info "Rolling back to backup: $latest_backup"
    restore_database "$latest_backup"
}

# Show service status
show_status() {
    log_info "Service status:"
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    
    log_info "Service health:"
    docker-compose -f "$COMPOSE_FILE" exec app node healthcheck.js && echo "App: Healthy" || echo "App: Unhealthy"
    docker-compose -f "$COMPOSE_FILE" exec db pg_isready -U helpboard_user -d helpboard && echo "Database: Ready" || echo "Database: Not ready"
    docker-compose -f "$COMPOSE_FILE" exec redis redis-cli ping && echo "Redis: Ready" || echo "Redis: Not ready"
}

# Main script logic
main() {
    local command="$1"
    
    case "$command" in
        "init")
            check_prerequisites
            load_env
            check_env_vars
            setup_ssl
            deploy_app
            log_info "HelpBoard deployment completed successfully!"
            log_info "Access your application at: https://helpboard.selfany.com"
            ;;
        "update")
            check_prerequisites
            load_env
            update_app
            ;;
        "ssl")
            setup_ssl
            ;;
        "ssl-renew")
            renew_ssl
            ;;
        "backup")
            backup_database
            ;;
        "restore")
            restore_database "$2"
            ;;
        "rollback")
            rollback
            ;;
        "logs")
            show_logs "$2"
            ;;
        "status")
            show_status
            ;;
        "stop")
            stop_services
            ;;
        "health")
            check_health
            ;;
        *)
            echo "Usage: $0 {init|update|ssl|ssl-renew|backup|restore|rollback|logs|status|stop|health}"
            echo
            echo "Commands:"
            echo "  init      - Initial deployment with SSL setup"
            echo "  update    - Update existing deployment"
            echo "  ssl       - Setup SSL certificates"
            echo "  ssl-renew - Renew SSL certificates"
            echo "  backup    - Create database backup"
            echo "  restore   - Restore database from backup"
            echo "  rollback  - Rollback to latest backup"
            echo "  logs      - Show logs (optionally specify service)"
            echo "  status    - Show service status"
            echo "  stop      - Stop all services"
            echo "  health    - Check application health"
            echo
            echo "Examples:"
            echo "  $0 init"
            echo "  $0 logs app"
            echo "  $0 restore backups/helpboard_backup_20241211_120000.sql.gz"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"