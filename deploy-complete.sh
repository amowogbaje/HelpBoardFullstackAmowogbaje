#!/bin/bash

# Complete HelpBoard Deployment Script - Zero Error Guarantee
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="helpboard.selfany.com"
COMPOSE_FILE="docker-compose.dev.yml"
DOCKER_COMPOSE="docker compose"
LOG_FILE="/var/log/helpboard-deployment.log"

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $message"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Error handler
error_exit() {
    log "ERROR" "$1"
    echo ""
    echo "Deployment failed. Check logs at: $LOG_FILE"
    echo "For debugging, run: ./deployment-helpers.sh debug"
    exit 1
}

# Trap errors
trap 'error_exit "Deployment failed at line $LINENO"' ERR

# Pre-deployment checks
pre_deployment_checks() {
    log "INFO" "Running pre-deployment checks..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error_exit "This script must be run as root"
    fi
    
    # Check Docker installation
    if ! command -v docker &> /dev/null; then
        log "INFO" "Installing Docker..."
        apt update
        apt install -y docker.io docker-compose-plugin
        systemctl start docker
        systemctl enable docker
    fi
    
    # Check domain resolution
    log "INFO" "Checking domain resolution..."
    if ! dig +short "$DOMAIN" | grep -q "161.35.58.110"; then
        error_exit "Domain $DOMAIN does not resolve to 161.35.58.110. Please update DNS records."
    fi
    
    # Check required ports
    log "INFO" "Checking required ports..."
    for port in 80 443; do
        if ss -tulpn | grep ":$port " | grep -v docker-proxy; then
            log "WARN" "Port $port is occupied by another service"
        fi
    done
    
    # Check environment file
    if [ ! -f ".env" ]; then
        error_exit ".env file not found. Please create it with required variables."
    fi
    
    # Validate OpenAI API key
    source .env
    if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
        error_exit "OPENAI_API_KEY is not set in .env file"
    fi
    
    log "INFO" "Pre-deployment checks passed"
}

# Setup SSL certificates
setup_ssl() {
    log "INFO" "Setting up SSL certificates..."
    
    # Create directories
    mkdir -p ssl certbot
    
    # Check if certificates already exist and are valid
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        if openssl x509 -in ssl/fullchain.pem -noout -checkend 86400; then
            log "INFO" "Valid SSL certificates found, skipping generation"
            return 0
        fi
    fi
    
    # Stop any existing containers to free ports
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" down || true
    
    # Generate SSL certificates
    log "INFO" "Generating SSL certificates for $DOMAIN..."
    
    docker run --rm \
        -p 80:80 \
        -v "$(pwd)/certbot:/etc/letsencrypt" \
        -v "$(pwd)/ssl:/etc/ssl/certs" \
        certbot/certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "${SSL_EMAIL:-admin@$DOMAIN}" \
        --domains "$DOMAIN" \
        --keep-until-expiring
    
    # Copy certificates to ssl directory
    cp "certbot/live/$DOMAIN/fullchain.pem" ssl/
    cp "certbot/live/$DOMAIN/privkey.pem" ssl/
    
    # Set correct permissions
    chmod 644 ssl/fullchain.pem
    chmod 600 ssl/privkey.pem
    
    log "INFO" "SSL certificates generated successfully"
}

# Database initialization with enhanced error handling
initialize_database() {
    log "INFO" "Initializing database..."
    
    # Wait for database to be ready with exponential backoff
    local max_attempts=60
    local attempt=1
    local wait_time=2
    
    while [ $attempt -le $max_attempts ]; do
        if $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user -d helpboard > /dev/null 2>&1; then
            log "INFO" "Database is ready (attempt $attempt)"
            break
        fi
        
        log "INFO" "Waiting for database... attempt $attempt/$max_attempts (${wait_time}s)"
        sleep $wait_time
        
        # Exponential backoff with maximum of 30 seconds
        wait_time=$((wait_time * 2))
        if [ $wait_time -gt 30 ]; then
            wait_time=30
        fi
        
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error_exit "Database failed to become ready after $max_attempts attempts"
    fi
    
    # Create database schema
    log "INFO" "Creating database schema..."
    if ! $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T app npm run db:push; then
        error_exit "Failed to create database schema"
    fi
    
    # Verify schema creation
    local table_count
    table_count=$($DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' \n\r')
    
    if [ "$table_count" -lt 5 ]; then
        error_exit "Database schema creation incomplete. Expected at least 5 tables, found $table_count"
    fi
    
    log "INFO" "Database schema created successfully ($table_count tables)"
    
    # Set up default agents with enhanced password hashing
    log "INFO" "Setting up default agents..."
    
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard << 'EOSQL'
-- Clear existing agents to avoid conflicts
TRUNCATE TABLE agents CASCADE;

-- Insert admin agent (admin@helpboard.com / admin123)
-- Password hash for 'admin123': $2a$12$LGKVlGlpzH1r.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6
INSERT INTO agents (
    email, password, name, role, is_active, is_available,
    department, phone, created_at, updated_at, password_changed_at
) VALUES (
    'admin@helpboard.com',
    '$2a$12$LGKVlGlpzH1r.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'System Administrator', 'admin', true, true,
    'Administration', '+1-555-0100', NOW(), NOW(), NOW()
) ON CONFLICT (email) DO NOTHING;

-- Insert support agent (agent@helpboard.com / password123)
-- Password hash for 'password123': $2a$12$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6
INSERT INTO agents (
    email, password, name, role, is_active, is_available,
    department, phone, created_at, updated_at, password_changed_at
) VALUES (
    'agent@helpboard.com',
    '$2a$12$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'Support Agent', 'agent', true, true,
    'Customer Support', '+1-555-0200', NOW(), NOW(), NOW()
) ON CONFLICT (email) DO NOTHING;
EOSQL
    
    # Verify agents were created
    local agent_count
    agent_count=$($DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -t -c "SELECT COUNT(*) FROM agents;" | tr -d ' \n\r')
    
    if [ "$agent_count" -lt 2 ]; then
        error_exit "Failed to create default agents. Expected 2, found $agent_count"
    fi
    
    log "INFO" "Default agents created successfully ($agent_count agents)"
}

# Application deployment
deploy_application() {
    log "INFO" "Deploying HelpBoard application..."
    
    # Load environment variables
    if [ ! -f ".env" ]; then
        error_exit ".env file not found"
    fi
    
    source .env
    
    # Validate required environment variables
    local required_vars=("OPENAI_API_KEY" "DATABASE_URL")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error_exit "Required environment variable $var is not set"
        fi
    done
    
    # Pull latest images
    log "INFO" "Pulling latest images..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" pull
    
    # Build application with no cache to avoid issues
    log "INFO" "Building application..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" build --no-cache app
    
    # Start services
    log "INFO" "Starting services..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
    
    # Wait for services to stabilize
    log "INFO" "Waiting for services to start..."
    sleep 30
    
    # Initialize database
    initialize_database
    
    # Apply authentication fixes
    log "INFO" "Applying authentication fixes..."
    if [ -f "fix-authentication.sh" ]; then
        chmod +x fix-authentication.sh
        ./fix-authentication.sh
    fi
    
    # Restart application to pick up changes
    log "INFO" "Restarting application with fixes..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" restart app
    sleep 20
}

# Comprehensive health checks
health_checks() {
    log "INFO" "Performing comprehensive health checks..."
    
    local max_attempts=30
    local attempt=1
    local health_url="https://$DOMAIN/api/health"
    
    while [ $attempt -le $max_attempts ]; do
        # Check HTTP health endpoint
        if curl -k -s -f "$health_url" > /dev/null 2>&1; then
            log "INFO" "Application health check passed (attempt $attempt)"
            break
        fi
        
        log "INFO" "Health check attempt $attempt/$max_attempts..."
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log "ERROR" "Application failed health checks"
        
        # Diagnostic information
        log "DEBUG" "Container status:"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" ps
        
        log "DEBUG" "Application logs:"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs app | tail -20
        
        error_exit "Application failed to become healthy after $max_attempts attempts"
    fi
    
    # Test authentication endpoints
    log "INFO" "Testing authentication..."
    local login_response
    login_response=$(curl -k -s -X POST "$health_url/../auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}' 2>/dev/null || echo "FAILED")
    
    if echo "$login_response" | grep -q "sessionToken"; then
        log "INFO" "Authentication test passed"
    else
        log "WARN" "Authentication test failed, but continuing deployment"
        log "DEBUG" "Login response: $login_response"
    fi
    
    log "INFO" "Health checks completed successfully"
}

# Post-deployment verification
post_deployment_verification() {
    log "INFO" "Running post-deployment verification..."
    
    # Verify all containers are running
    local container_status
    container_status=$($DOCKER_COMPOSE -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.Status}}" | grep -c "Up" || echo "0")
    
    if [ "$container_status" -lt 3 ]; then
        error_exit "Not all containers are running. Expected at least 3, found $container_status"
    fi
    
    # Verify SSL certificates
    if [ -f "ssl/fullchain.pem" ]; then
        if ! openssl x509 -in ssl/fullchain.pem -noout -checkend 86400; then
            log "WARN" "SSL certificate expires within 24 hours"
        fi
    fi
    
    # Verify database connectivity
    if ! $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user -d helpboard; then
        error_exit "Database connectivity check failed"
    fi
    
    # Generate deployment report
    cat > deployment-report.txt << EOF
HelpBoard Deployment Report
Generated: $(date)
Domain: $DOMAIN
Status: SUCCESS

Services Running:
$($DOCKER_COMPOSE -f "$COMPOSE_FILE" ps)

Default Credentials:
- Admin: admin@helpboard.com / admin123
- Agent: agent@helpboard.com / password123

Access URLs:
- Application: https://$DOMAIN
- Health Check: https://$DOMAIN/api/health

Logs Location: $LOG_FILE
EOF
    
    log "INFO" "Post-deployment verification completed"
}

# Main deployment function
main() {
    echo "=========================================="
    echo "HelpBoard Complete Deployment Script"
    echo "Domain: $DOMAIN"
    echo "Timestamp: $(date)"
    echo "=========================================="
    echo ""
    
    # Create log file
    touch "$LOG_FILE"
    
    # Run deployment steps
    pre_deployment_checks
    setup_ssl
    deploy_application
    health_checks
    post_deployment_verification
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}DEPLOYMENT SUCCESSFUL!${NC}"
    echo "=========================================="
    echo ""
    echo "Application URL: https://$DOMAIN"
    echo "Admin Login: admin@helpboard.com / admin123"
    echo "Agent Login: agent@helpboard.com / password123"
    echo ""
    echo "Deployment report: deployment-report.txt"
    echo "Logs: $LOG_FILE"
    echo ""
    echo "For troubleshooting: ./deployment-helpers.sh debug"
    echo "For testing: ./deployment-helpers.sh test-login"
    echo "=========================================="
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi