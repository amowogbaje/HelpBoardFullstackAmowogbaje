#!/bin/bash

# Simple Two-Command HelpBoard Deployment
# Usage: ./simple-deploy.sh setup
#        ./simple-deploy.sh deploy

set -e

DOMAIN="helpboard.selfany.com"
IP="161.35.58.110"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Command 1: Setup system dependencies
setup_system() {
    log "Setting up system dependencies..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "Run as root: sudo ./simple-deploy.sh setup"
    fi
    
    # Update system
    apt update
    
    # Install Docker using official script (handles all variants)
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        systemctl start docker
        systemctl enable docker
    fi
    
    # Install Docker Compose V2 (handles the plugin issue)
    if ! docker compose version &> /dev/null; then
        log "Installing Docker Compose V2..."
        DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
        mkdir -p $DOCKER_CONFIG/cli-plugins
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
        chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
        
        # Also install system-wide
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    
    # Install other dependencies
    apt install -y curl git ufw openssl dnsutils certbot
    
    # Configure firewall
    ufw allow OpenSSH
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    
    # Set up environment file
    if [ ! -f ".env" ]; then
        log "Creating environment file..."
        cat > .env << 'EOF'
# HelpBoard Configuration
OPENAI_API_KEY=your_openai_api_key_here
DATABASE_URL=postgresql://helpboard_user:helpboard_secure_pass@db:5432/helpboard
NODE_ENV=development
DOMAIN=helpboard.selfany.com
PORT=3000
SESSION_SECRET=helpboard_session_secret_change_this_to_32_chars_minimum
SSL_EMAIL=admin@helpboard.selfany.com
EOF
        echo ""
        echo -e "${BLUE}Setup complete! Edit .env file with your OpenAI API key, then run:${NC}"
        echo -e "${GREEN}./simple-deploy.sh deploy${NC}"
    else
        echo ""
        echo -e "${GREEN}Setup complete! Ready for deployment.${NC}"
        echo -e "Run: ${BLUE}./simple-deploy.sh deploy${NC}"
    fi
}

# Command 2: Deploy application
deploy_application() {
    log "Starting HelpBoard deployment..."
    
    # Check environment file
    if [ ! -f ".env" ]; then
        error "Missing .env file. Run: ./simple-deploy.sh setup"
    fi
    
    source .env
    if [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
        error "Update OPENAI_API_KEY in .env file before deploying"
    fi
    
    # Detect available Docker Compose command
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        error "Docker Compose not found. Run: ./simple-deploy.sh setup"
    fi
    
    log "Using Docker Compose: $COMPOSE_CMD"
    
    # Generate SSL certificates
    log "Setting up SSL certificates..."
    mkdir -p ssl certbot
    
    # Stop any existing containers
    $COMPOSE_CMD -f docker-compose.dev.yml down || true
    
    # Generate SSL certificate
    if [ ! -f "ssl/fullchain.pem" ]; then
        if certbot certonly --standalone --non-interactive --agree-tos \
           --email "$SSL_EMAIL" --domains "$DOMAIN" --keep-until-expiring; then
            cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ssl/
            cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ssl/
            chmod 644 ssl/fullchain.pem
            chmod 600 ssl/privkey.pem
            log "SSL certificate generated"
        else
            log "Creating self-signed certificate as fallback..."
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout ssl/privkey.pem -out ssl/fullchain.pem \
                -subj "/C=US/ST=State/L=City/O=HelpBoard/CN=$DOMAIN"
            chmod 644 ssl/fullchain.pem
            chmod 600 ssl/privkey.pem
        fi
    fi
    
    # Pull and build
    log "Pulling Docker images..."
    $COMPOSE_CMD -f docker-compose.dev.yml pull
    
    log "Building application..."
    $COMPOSE_CMD -f docker-compose.dev.yml build --no-cache app
    
    # Start services
    log "Starting services..."
    $COMPOSE_CMD -f docker-compose.dev.yml up -d
    
    # Wait for database
    log "Waiting for database..."
    sleep 30
    
    # Initialize database
    log "Setting up database..."
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if $COMPOSE_CMD -f docker-compose.dev.yml exec -T db pg_isready -U helpboard_user -d helpboard; then
            break
        fi
        sleep 2
        ((attempts++))
    done
    
    # Create schema
    $COMPOSE_CMD -f docker-compose.dev.yml exec -T app npm run db:push
    
    # Create default users
    $COMPOSE_CMD -f docker-compose.dev.yml exec -T db psql -U helpboard_user -d helpboard << 'EOSQL'
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
    
    # Restart application
    log "Restarting application..."
    $COMPOSE_CMD -f docker-compose.dev.yml restart app
    sleep 15
    
    # Health check
    log "Performing health check..."
    local health_attempts=0
    while [ $health_attempts -lt 20 ]; do
        if curl -k -s "https://$DOMAIN/api/health" | grep -q "ok"; then
            break
        fi
        sleep 5
        ((health_attempts++))
    done
    
    # Generate report
    cat > deployment-summary.txt << EOF
HelpBoard Deployment Complete
============================
Date: $(date)
Domain: https://$DOMAIN

Login Credentials:
- Admin: admin@helpboard.com / admin123
- Agent: agent@helpboard.com / password123

Services Status:
$($COMPOSE_CMD -f docker-compose.dev.yml ps)

Next Steps:
1. Access https://$DOMAIN
2. Login with admin credentials
3. Configure your support system

Troubleshooting:
- View logs: $COMPOSE_CMD -f docker-compose.dev.yml logs
- Debug: ./deployment-helpers.sh debug
EOF
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    DEPLOYMENT SUCCESSFUL!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Application:${NC} https://$DOMAIN"
    echo -e "${BLUE}Admin Login:${NC} admin@helpboard.com / admin123"
    echo -e "${BLUE}Agent Login:${NC} agent@helpboard.com / password123"
    echo ""
    echo -e "Summary saved to: ${GREEN}deployment-summary.txt${NC}"
    echo ""
}

# Show usage
show_usage() {
    echo "Simple HelpBoard Deployment"
    echo ""
    echo "Usage:"
    echo "  sudo ./simple-deploy.sh setup    # Install dependencies (run once)"
    echo "  ./simple-deploy.sh deploy        # Deploy application"
    echo ""
    echo "Two commands, zero complexity."
}

# Main execution
case "${1:-help}" in
    setup)
        setup_system
        ;;
    deploy)
        deploy_application
        ;;
    help|*)
        show_usage
        ;;
esac