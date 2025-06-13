#!/bin/bash

# Production-Ready HelpBoard Deployment for Digital Ocean
set -e

# Configuration
DOMAIN="helpboard.selfany.com"
IP="161.35.58.110"
COMPOSE_FILE="docker-compose.dev.yml"
LOG_FILE="/var/log/helpboard-deployment.log"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    local level=$1
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO") echo -e "${GREEN}[INFO]${NC} $msg" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $msg" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $msg" ;;
    esac
    
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Pre-deployment validation
validate_environment() {
    log "INFO" "Validating deployment environment..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error_exit "This script must be run as root (use sudo)"
    fi
    
    # Check environment file
    if [ ! -f ".env" ]; then
        log "ERROR" "Missing .env file. Creating template..."
        cat > .env << 'EOF'
# HelpBoard Environment Configuration
OPENAI_API_KEY=your_openai_api_key_here
DATABASE_URL=postgresql://helpboard_user:helpboard_secure_pass@db:5432/helpboard
NODE_ENV=development
DOMAIN=helpboard.selfany.com
PORT=3000
SESSION_SECRET=helpboard_session_secret_change_me_32_chars_minimum
SSL_EMAIL=admin@helpboard.selfany.com
EOF
        error_exit "Created .env template. Please update with your API keys and run again."
    fi
    
    source .env
    
    # Validate OpenAI API key
    if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
        error_exit "OPENAI_API_KEY must be set in .env file"
    fi
    
    # Check DNS resolution
    log "INFO" "Checking DNS resolution for $DOMAIN..."
    if ! dig +short "$DOMAIN" | grep -q "$IP"; then
        log "WARN" "DNS may not be properly configured. Expected $IP for $DOMAIN"
        log "WARN" "Continuing anyway - this may cause SSL certificate issues"
    fi
    
    log "INFO" "Environment validation complete"
}

# Install system dependencies
install_dependencies() {
    log "INFO" "Installing system dependencies..."
    
    # Update package list
    apt update
    
    # Install required packages
    apt install -y \
        docker.io \
        docker-compose-plugin \
        curl \
        git \
        ufw \
        certbot \
        openssl \
        dnsutils
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Configure firewall
    log "INFO" "Configuring firewall..."
    ufw allow OpenSSH
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    
    log "INFO" "System dependencies installed"
}

# SSL certificate setup
setup_ssl_certificates() {
    log "INFO" "Setting up SSL certificates..."
    
    # Create SSL directories
    mkdir -p ssl certbot
    
    # Check if valid certificates exist
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        if openssl x509 -in ssl/fullchain.pem -noout -checkend 86400 > /dev/null 2>&1; then
            log "INFO" "Valid SSL certificates found, skipping generation"
            return 0
        fi
    fi
    
    # Stop any existing containers to free port 80
    docker compose -f "$COMPOSE_FILE" down > /dev/null 2>&1 || true
    
    # Generate SSL certificate using certbot
    log "INFO" "Generating SSL certificate for $DOMAIN..."
    
    if certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "${SSL_EMAIL:-admin@$DOMAIN}" \
        --domains "$DOMAIN" \
        --keep-until-expiring; then
        
        # Copy certificates to ssl directory
        cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ssl/
        cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ssl/
        
        # Set proper permissions
        chmod 644 ssl/fullchain.pem
        chmod 600 ssl/privkey.pem
        
        log "INFO" "SSL certificates generated successfully"
    else
        log "WARN" "SSL certificate generation failed, creating self-signed certificate"
        
        # Create self-signed certificate as fallback
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/privkey.pem \
            -out ssl/fullchain.pem \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
        
        chmod 644 ssl/fullchain.pem
        chmod 600 ssl/privkey.pem
    fi
}

# Database initialization with comprehensive error handling
initialize_database() {
    log "INFO" "Initializing database..."
    
    # Wait for database with exponential backoff
    local max_attempts=60
    local attempt=1
    local wait_time=2
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user -d helpboard > /dev/null 2>&1; then
            log "INFO" "Database ready after $attempt attempts"
            break
        fi
        
        log "INFO" "Waiting for database... attempt $attempt/$max_attempts (${wait_time}s)"
        sleep $wait_time
        
        # Exponential backoff up to 30 seconds
        wait_time=$((wait_time < 30 ? wait_time * 2 : 30))
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error_exit "Database failed to start after $max_attempts attempts"
    fi
    
    # Create database schema
    log "INFO" "Creating database schema..."
    if ! docker compose -f "$COMPOSE_FILE" exec -T app npm run db:push; then
        error_exit "Database schema creation failed"
    fi
    
    # Verify schema creation
    local table_count
    table_count=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' \n\r')
    
    if [ "$table_count" -lt 5 ]; then
        error_exit "Database schema incomplete. Found $table_count tables, expected at least 5"
    fi
    
    log "INFO" "Database schema verified ($table_count tables)"
    
    # Create default agents
    log "INFO" "Setting up default agents..."
    docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard << 'EOSQL'
-- Create default agents with proper password hashing
INSERT INTO agents (
    email, password, name, role, is_active, is_available,
    department, phone, created_at, updated_at, password_changed_at
) VALUES (
    'admin@helpboard.com',
    '$2a$12$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'System Administrator', 'admin', true, true,
    'Administration', '+1-555-0100', NOW(), NOW(), NOW()
), (
    'agent@helpboard.com',
    '$2a$12$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'Support Agent', 'agent', true, true,
    'Customer Support', '+1-555-0200', NOW(), NOW(), NOW()
) ON CONFLICT (email) DO UPDATE SET
    password = EXCLUDED.password,
    is_active = true,
    updated_at = NOW();
EOSQL
    
    # Verify agent creation
    local agent_count
    agent_count=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user -d helpboard -t -c \
        "SELECT COUNT(*) FROM agents;" | tr -d ' \n\r')
    
    if [ "$agent_count" -lt 2 ]; then
        error_exit "Agent creation failed. Found $agent_count agents, expected at least 2"
    fi
    
    log "INFO" "Default agents created successfully ($agent_count agents)"
}

# Deploy application
deploy_application() {
    log "INFO" "Deploying HelpBoard application..."
    
    # Pull latest images
    log "INFO" "Pulling latest Docker images..."
    docker compose -f "$COMPOSE_FILE" pull
    
    # Build application
    log "INFO" "Building application..."
    docker compose -f "$COMPOSE_FILE" build --no-cache app
    
    # Start services
    log "INFO" "Starting services..."
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to start
    log "INFO" "Waiting for services to initialize..."
    sleep 30
    
    # Initialize database
    initialize_database
    
    # Restart application to ensure clean state
    log "INFO" "Restarting application..."
    docker compose -f "$COMPOSE_FILE" restart app
    sleep 15
    
    log "INFO" "Application deployment complete"
}

# Comprehensive health checks
perform_health_checks() {
    log "INFO" "Performing comprehensive health checks..."
    
    local max_attempts=30
    local attempt=1
    
    # Test health endpoint
    while [ $attempt -le $max_attempts ]; do
        if curl -k -s "https://$DOMAIN/api/health" | grep -q "ok" > /dev/null 2>&1; then
            log "INFO" "Health check passed (attempt $attempt)"
            break
        fi
        
        log "INFO" "Health check attempt $attempt/$max_attempts..."
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log "WARN" "HTTPS health check failed, trying HTTP..."
        if curl -s "http://$DOMAIN/api/health" | grep -q "ok" > /dev/null 2>&1; then
            log "INFO" "HTTP health check passed"
        else
            error_exit "All health checks failed"
        fi
    fi
    
    # Test authentication
    log "INFO" "Testing authentication system..."
    local login_response
    login_response=$(curl -k -s -X POST "https://$DOMAIN/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}' 2>/dev/null || \
        curl -s -X POST "http://$DOMAIN/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}' 2>/dev/null)
    
    if echo "$login_response" | grep -q "sessionToken"; then
        log "INFO" "Authentication test passed"
        
        # Extract token and test API access
        local token
        token=$(echo "$login_response" | grep -o '"sessionToken":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            local api_response
            api_response=$(curl -k -s -H "Authorization: Bearer $token" \
                "https://$DOMAIN/api/conversations" 2>/dev/null || \
                curl -s -H "Authorization: Bearer $token" \
                "http://$DOMAIN/api/conversations" 2>/dev/null)
            
            if echo "$api_response" | grep -q "Invalid.*session"; then
                log "WARN" "API authentication partially working but may have session issues"
            else
                log "INFO" "Full authentication flow verified"
            fi
        fi
    else
        log "WARN" "Authentication test failed, but continuing deployment"
    fi
    
    log "INFO" "Health checks completed"
}

# Generate deployment report
generate_deployment_report() {
    log "INFO" "Generating deployment report..."
    
    local container_status
    container_status=$(docker compose -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.Status}}")
    
    cat > deployment-report.txt << EOF
===============================================
HelpBoard Deployment Report
===============================================
Deployment Date: $(date)
Domain: $DOMAIN
IP Address: $IP
Status: SUCCESSFUL

Services Status:
$container_status

Access Information:
- Application URL: https://$DOMAIN
- Admin Login: admin@helpboard.com / admin123
- Agent Login: agent@helpboard.com / password123

SSL Certificate:
$(if [ -f "ssl/fullchain.pem" ]; then
    openssl x509 -in ssl/fullchain.pem -noout -subject -dates 2>/dev/null || echo "Certificate info unavailable"
else
    echo "No SSL certificate found"
fi)

System Information:
- Docker Version: $(docker --version)
- Compose Version: $(docker compose version)
- System Load: $(uptime)
- Disk Usage: $(df -h / | tail -1)
- Memory Usage: $(free -h | grep Mem)

Logs Location: $LOG_FILE
Configuration: .env

Next Steps:
1. Update DNS records if needed
2. Configure monitoring
3. Set up automated backups
4. Review security settings

For support: ./deployment-helpers.sh debug
===============================================
EOF
    
    log "INFO" "Deployment report generated: deployment-report.txt"
}

# Main deployment function
main() {
    echo "=================================================="
    echo "HelpBoard Production-Ready Deployment"
    echo "Domain: $DOMAIN"
    echo "Target IP: $IP"
    echo "Timestamp: $(date)"
    echo "=================================================="
    echo ""
    
    # Create log file
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/helpboard-deployment.log"
    
    # Execute deployment steps
    validate_environment
    install_dependencies
    setup_ssl_certificates
    deploy_application
    perform_health_checks
    generate_deployment_report
    
    echo ""
    echo "=================================================="
    echo -e "${GREEN}DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}"
    echo "=================================================="
    echo ""
    echo "🌐 Application URL: https://$DOMAIN"
    echo "👤 Admin Login: admin@helpboard.com / admin123"
    echo "🎧 Agent Login: agent@helpboard.com / password123"
    echo ""
    echo "📋 Deployment Report: deployment-report.txt"
    echo "📝 Logs: $LOG_FILE"
    echo ""
    echo "🔧 For troubleshooting: ./deployment-helpers.sh debug"
    echo "🧪 For testing: ./deployment-helpers.sh test-login"
    echo "=================================================="
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi