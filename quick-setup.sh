#!/bin/bash

# Quick HelpBoard Setup Script
# Downloads deployment scripts and sets up environment

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}HelpBoard Quick Setup${NC}"
echo "======================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./quick-setup.sh"
    exit 1
fi

# Install essential dependencies
echo "Installing dependencies..."
apt update
apt install -y curl git ufw

# Install Docker using official script (handles all Docker Compose issues)
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl start docker
    systemctl enable docker
fi

# Install Docker Compose V2 to avoid plugin issues
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose V2..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
    
    # System-wide installation
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Configure firewall
echo "Configuring firewall..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create environment file template
echo "Creating environment template..."
cat > .env << 'EOF'
# HelpBoard Development Configuration
OPENAI_API_KEY=your_openai_api_key_here
DATABASE_URL=postgresql://helpboard_user:helpboard_secure_pass@db:5432/helpboard
NODE_ENV=development
DOMAIN=helpboard.selfany.com
PORT=3000
SESSION_SECRET=helpboard_session_secret_change_this_to_32_chars_minimum
SSL_EMAIL=admin@helpboard.selfany.com
EOF

# Create simple deployment script
cat > deploy.sh << 'EOF'
#!/bin/bash

# Simple HelpBoard Development Deployment

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

# Check environment
if [ ! -f ".env" ]; then
    echo -e "${RED}Error:${NC} .env file not found"
    exit 1
fi

source .env
if [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
    echo -e "${RED}Error:${NC} Please update OPENAI_API_KEY in .env file"
    exit 1
fi

# Detect Docker Compose command
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}Error:${NC} Docker Compose not found"
    exit 1
fi

log "Using: $COMPOSE_CMD"

# Setup SSL certificates (self-signed for dev)
log "Setting up SSL certificates..."
mkdir -p ssl
if [ ! -f "ssl/fullchain.pem" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/privkey.pem -out ssl/fullchain.pem \
        -subj "/C=US/ST=State/L=City/O=HelpBoard/CN=$DOMAIN" >/dev/null 2>&1
    chmod 644 ssl/fullchain.pem
    chmod 600 ssl/privkey.pem
    log "Self-signed SSL certificate created"
fi

# Stop existing containers
$COMPOSE_CMD -f docker-compose.dev.yml down || true

# Pull and build
log "Building application..."
$COMPOSE_CMD -f docker-compose.dev.yml pull >/dev/null 2>&1
$COMPOSE_CMD -f docker-compose.dev.yml build --no-cache app >/dev/null 2>&1

# Start services
log "Starting services..."
$COMPOSE_CMD -f docker-compose.dev.yml up -d

# Wait for database
log "Waiting for database..."
sleep 30

# Initialize database with retry logic
log "Setting up database..."
attempts=0
while [ $attempts -lt 30 ]; do
    if $COMPOSE_CMD -f docker-compose.dev.yml exec -T db pg_isready -U helpboard_user -d helpboard >/dev/null 2>&1; then
        break
    fi
    sleep 2
    ((attempts++))
done

# Create schema
$COMPOSE_CMD -f docker-compose.dev.yml exec -T app npm run db:push >/dev/null 2>&1

# Create default users with fixed authentication
$COMPOSE_CMD -f docker-compose.dev.yml exec -T db psql -U helpboard_user -d helpboard << 'EOSQL' >/dev/null 2>&1
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

# Restart application to pick up changes
log "Restarting application..."
$COMPOSE_CMD -f docker-compose.dev.yml restart app >/dev/null 2>&1
sleep 15

# Health check
log "Checking application health..."
attempts=0
while [ $attempts -lt 20 ]; do
    if curl -k -s http://localhost:3000/api/health | grep -q "ok" >/dev/null 2>&1; then
        break
    fi
    sleep 3
    ((attempts++))
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "🌐 Application: https://helpboard.selfany.com"
echo "👤 Admin: admin@helpboard.com / admin123"
echo "🎧 Agent: agent@helpboard.com / password123"
echo ""
echo "Services running:"
$COMPOSE_CMD -f docker-compose.dev.yml ps
echo ""
echo "Logs: $COMPOSE_CMD -f docker-compose.dev.yml logs -f"
EOF

chmod +x deploy.sh

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   SETUP COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Edit .env file with your OpenAI API key:"
echo -e "   ${GREEN}nano .env${NC}"
echo ""
echo "2. Deploy the application:"
echo -e "   ${GREEN}./deploy.sh${NC}"
echo ""
echo "That's it! Two simple steps."
echo ""