#!/bin/bash

# Complete HelpBoard Setup Script for Digital Ocean
# Handles Node.js installation, directory structure, and deployment

set -e

# Configuration
DOMAIN="helpboard.selfany.com"
IP="161.35.58.110"
APP_DIR="/opt/helpboard"
REPO_URL="https://github.com/your-org/helpboard.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root: sudo $0"
        exit 1
    fi
    
    # Get actual user for later use
    if [ -n "$SUDO_USER" ]; then
        ACTUAL_USER="$SUDO_USER"
        USER_HOME="/home/$SUDO_USER"
    else
        ACTUAL_USER="root"
        USER_HOME="/root"
    fi
    
    log_info "Running as root, actual user: $ACTUAL_USER"
}

# Update system and install essential packages
update_system() {
    log_info "Updating system packages..."
    apt update && apt upgrade -y
    apt install -y curl wget gnupg2 software-properties-common apt-transport-https \
                   ca-certificates lsb-release ufw fail2ban git build-essential \
                   python3 python3-pip jq unzip
}

# Install Node.js 20 LTS
install_nodejs() {
    log_info "Installing Node.js 20 LTS..."
    
    # Remove any existing Node.js installations
    apt remove -y nodejs npm 2>/dev/null || true
    
    # Install Node.js 20 via NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Verify installation
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    
    log_info "Node.js version: $node_version"
    log_info "npm version: $npm_version"
    
    # Set npm global directory for non-root user
    if [ "$ACTUAL_USER" != "root" ]; then
        sudo -u "$ACTUAL_USER" mkdir -p "$USER_HOME/.npm-global"
        sudo -u "$ACTUAL_USER" npm config set prefix "$USER_HOME/.npm-global"
        echo 'export PATH=~/.npm-global/bin:$PATH' >> "$USER_HOME/.profile"
    fi
}

# Install Docker and Docker Compose
install_docker() {
    log_info "Installing Docker..."
    
    # Remove old Docker versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    usermod -aG docker "$ACTUAL_USER"
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    log_info "Docker installed successfully"
}

# Configure firewall
setup_firewall() {
    log_info "Configuring firewall..."
    
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    
    log_info "Firewall configured"
}

# Setup application directory and clone repository
setup_application() {
    log_info "Setting up application directory..."
    
    # Create application directory
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    
    # If directory is not empty, backup existing content
    if [ "$(ls -A $APP_DIR 2>/dev/null)" ]; then
        log_warn "Directory not empty, creating backup..."
        mv "$APP_DIR" "${APP_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$APP_DIR"
        cd "$APP_DIR"
    fi
    
    # Method 1: Try git clone (if repository is available)
    if git ls-remote "$REPO_URL" &>/dev/null; then
        log_info "Cloning repository from $REPO_URL..."
        git clone "$REPO_URL" temp_repo
        mv temp_repo/* .
        mv temp_repo/.* . 2>/dev/null || true
        rm -rf temp_repo
    else
        log_warn "Repository not accessible, will use local files..."
        
        # Method 2: Check if running from source directory
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "$script_dir/package.json" ] && [ -f "$script_dir/docker-compose.prod.yml" ]; then
            log_info "Copying files from source directory..."
            cp -r "$script_dir"/* .
            cp -r "$script_dir"/.* . 2>/dev/null || true
        else
            log_error "No repository access and no source files found"
            log_error "Please ensure you have the HelpBoard source files available"
            exit 1
        fi
    fi
    
    # Set proper ownership
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$APP_DIR"
    
    log_info "Application files setup complete"
}

# Create environment file
create_environment() {
    log_info "Creating environment configuration..."
    
    if [ ! -f "$APP_DIR/.env.example" ]; then
        log_warn ".env.example not found, creating basic environment file..."
        cat > "$APP_DIR/.env" << EOF
# Database Configuration
DB_PASSWORD=helpboard_secure_password_$(openssl rand -hex 12)
REDIS_PASSWORD=redis_secure_password_$(openssl rand -hex 12)

# OpenAI API Key (REQUIRED - Please add your key)
OPENAI_API_KEY=your_openai_api_key_here

# Session Security
SESSION_SECRET=$(openssl rand -base64 32)

# Production Settings
NODE_ENV=production
CORS_ORIGIN=https://$DOMAIN
TRUST_PROXY=true
DOMAIN=$DOMAIN
EOF
    else
        cp "$APP_DIR/.env.example" "$APP_DIR/.env"
        
        # Update domain and generate secure passwords
        sed -i "s|DOMAIN=.*|DOMAIN=$DOMAIN|g" "$APP_DIR/.env"
        sed -i "s|CORS_ORIGIN=.*|CORS_ORIGIN=https://$DOMAIN|g" "$APP_DIR/.env"
        
        # Generate secure passwords if they contain placeholder values
        if grep -q "your_secure_password" "$APP_DIR/.env"; then
            local db_password="helpboard_secure_$(openssl rand -hex 12)"
            local redis_password="redis_secure_$(openssl rand -hex 12)"
            local session_secret="$(openssl rand -base64 32)"
            
            sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$db_password|g" "$APP_DIR/.env"
            sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$redis_password|g" "$APP_DIR/.env"
            sed -i "s|SESSION_SECRET=.*|SESSION_SECRET=$session_secret|g" "$APP_DIR/.env"
        fi
    fi
    
    chown "$ACTUAL_USER:$ACTUAL_USER" "$APP_DIR/.env"
    chmod 600 "$APP_DIR/.env"
    
    log_info "Environment file created at $APP_DIR/.env"
    log_warn "IMPORTANT: Edit $APP_DIR/.env and add your OPENAI_API_KEY"
}

# Install application dependencies
install_dependencies() {
    log_info "Installing application dependencies..."
    
    cd "$APP_DIR"
    
    # Install as the actual user, not root
    sudo -u "$ACTUAL_USER" npm ci
    
    log_info "Dependencies installed successfully"
}

# Test application build
test_build() {
    log_info "Testing application build..."
    
    cd "$APP_DIR"
    
    # Run build as actual user
    sudo -u "$ACTUAL_USER" NODE_ENV=production npm run build
    
    # Verify build outputs
    if [ ! -d "dist/public" ]; then
        log_error "Frontend build failed - dist/public not found"
        exit 1
    fi
    
    if [ ! -f "dist/index.js" ]; then
        log_error "Backend build failed - dist/index.js not found"
        exit 1
    fi
    
    log_info "Build test passed successfully"
}

# Create deployment scripts
create_deployment_scripts() {
    log_info "Creating deployment scripts..."
    
    # Make scripts executable
    chmod +x "$APP_DIR"/*.sh 2>/dev/null || true
    
    # Ensure ownership
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$APP_DIR"
    
    log_info "Deployment scripts ready"
}

# Display setup summary
show_summary() {
    log_info "HelpBoard setup completed successfully!"
    echo
    echo "=== Setup Summary ==="
    echo "Application Directory: $APP_DIR"
    echo "Domain: $DOMAIN"
    echo "IP Address: $IP"
    echo "Node.js Version: $(node --version)"
    echo "Docker Version: $(docker --version)"
    echo
    echo "=== Next Steps ==="
    echo "1. Edit the environment file:"
    echo "   nano $APP_DIR/.env"
    echo
    echo "2. Add your OpenAI API key to the .env file"
    echo
    echo "3. Deploy the application:"
    echo "   cd $APP_DIR"
    echo "   sudo -u $ACTUAL_USER ./deploy-fixed.sh full"
    echo
    echo "4. Check deployment status:"
    echo "   ./deploy-fixed.sh status"
    echo
    echo "=== Important Notes ==="
    echo "- Your application will be available at: https://$DOMAIN"
    echo "- Default login: agent@helpboard.com / password123"
    echo "- SSL certificates will be automatically generated"
    echo "- All services will run in Docker containers"
    echo
}

# Main execution
main() {
    log_info "Starting complete HelpBoard setup for Digital Ocean..."
    
    check_root
    update_system
    install_nodejs
    install_docker
    setup_firewall
    setup_application
    create_environment
    install_dependencies
    test_build
    create_deployment_scripts
    show_summary
    
    log_info "Setup completed! You can now proceed with deployment."
}

# Run main function
main "$@"