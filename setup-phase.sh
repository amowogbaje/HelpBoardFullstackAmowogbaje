#!/bin/bash

# HelpBoard Setup Phase - Digital Ocean Droplet
# This script prepares the environment and guides .env configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[SETUP]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${GREEN}[STEP]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

DOMAIN="helpboard.selfany.com"
DEPLOY_DIR="/opt/helpboard"

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Verify Digital Ocean environment
verify_do_environment() {
    log_step "Verifying Digital Ocean droplet environment..."
    
    # Check if on DO droplet
    if curl -s --connect-timeout 2 http://169.254.169.254/metadata/v1/id > /dev/null 2>&1; then
        local droplet_id=$(curl -s http://169.254.169.254/metadata/v1/id)
        log_success "Running on DO droplet (ID: $droplet_id)"
    else
        log_warning "Not on DO droplet or metadata unavailable"
    fi
    
    # Check system resources
    local memory=$(free -h | awk '/^Mem:/ {print $2}')
    local disk=$(df -h / | awk 'NR==2 {print $4}')
    log_info "Available memory: $memory"
    log_info "Available disk space: $disk"
    
    # Verify minimum requirements
    local mem_mb=$(free -m | awk '/^Mem:/ {print $2}')
    if [ "$mem_mb" -lt 1900 ]; then
        log_error "Insufficient memory: ${mem_mb}MB (minimum 2GB required)"
        exit 1
    fi
    
    log_success "System resources sufficient"
}

# Clean previous installations completely
clean_previous_installation() {
    log_step "Cleaning any previous HelpBoard installations..."
    
    # Stop and remove all containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remove all Docker networks
    docker network prune -f 2>/dev/null || true
    
    # Remove all Docker volumes
    docker volume prune -f 2>/dev/null || true
    
    # Remove all Docker images
    docker image prune -af 2>/dev/null || true
    
    # Kill processes on critical ports
    for port in 80 443 5000 5432 6379; do
        local pids=$(lsof -ti:$port 2>/dev/null || true)
        if [ -n "$pids" ]; then
            log_info "Killing processes on port $port"
            echo "$pids" | xargs -r kill -9 2>/dev/null || true
        fi
    done
    
    # Stop system services that might interfere
    systemctl stop apache2 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    systemctl disable apache2 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true
    
    # Remove previous deployment directory if exists
    if [ -d "$DEPLOY_DIR" ]; then
        log_info "Removing previous deployment directory"
        rm -rf "$DEPLOY_DIR"
    fi
    
    log_success "Previous installations cleaned"
}

# Install required system packages
install_system_packages() {
    log_step "Installing required system packages..."
    
    # Update package lists
    apt update
    
    # Install essential packages
    apt install -y \
        curl \
        wget \
        git \
        unzip \
        ufw \
        lsof \
        htop \
        nano \
        openssl \
        ca-certificates \
        gnupg \
        lsb-release
    
    log_success "System packages installed"
}

# Configure git for repository operations
configure_git() {
    log_step "Configuring git..."
    
    # Set global git configuration
    git config --global user.email "amowogbajegideon@gmail.com"
    git config --global user.name "Gideon Amowogbaje"
    
    log_success "Git configuration completed"
}

# Install Docker and Docker Compose
install_docker() {
    log_step "Installing Docker and Docker Compose..."
    
    # Remove old Docker versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update and install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Verify installation
    if docker --version && docker compose version; then
        log_success "Docker and Docker Compose installed successfully"
    else
        log_error "Docker installation failed"
        exit 1
    fi
}

# Configure firewall
configure_firewall() {
    log_step "Configuring firewall..."
    
    # Reset UFW
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow 22/tcp
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall
    ufw --force enable
    
    log_success "Firewall configured"
}

# Clone repository
clone_repository() {
    log_step "Cloning HelpBoard repository..."
    
    # Create deployment directory
    mkdir -p "$DEPLOY_DIR"
    cd "$DEPLOY_DIR"
    
    # Clone the repository (assuming it's available)
    # Note: User should provide the actual repository URL
    log_info "Repository should be cloned to $DEPLOY_DIR"
    log_info "If repository exists, files should be uploaded manually to this directory"
    
    # For now, create the basic structure
    mkdir -p ssl certbot/www certbot/conf
    
    log_success "Deployment directory prepared"
}

# Create environment file template
create_env_template() {
    log_step "Creating .env template..."
    
    cat > "$DEPLOY_DIR/.env.example" << 'EOF'
# Database Configuration
DATABASE_URL=postgresql://helpboard_user:secure_password_here@db:5432/helpboard_db
PGHOST=db
PGPORT=5432
PGDATABASE=helpboard_db
PGUSER=helpboard_user
PGPASSWORD=secure_password_here

# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here

# Session Configuration
SESSION_SECRET=your_very_long_random_session_secret_here

# Application Configuration
NODE_ENV=development
PORT=5000

# Domain Configuration
DOMAIN=helpboard.selfany.com
EOF
    
    log_success ".env template created at $DEPLOY_DIR/.env.example"
}

# Generate secure passwords
generate_secure_configs() {
    log_step "Generating secure configuration values..."
    
    # Generate random values
    local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local session_secret=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
    
    # Create actual .env file with generated values
    cat > "$DEPLOY_DIR/.env" << EOF
# Database Configuration
DATABASE_URL=postgresql://helpboard_user:${db_password}@db:5432/helpboard_db
PGHOST=db
PGPORT=5432
PGDATABASE=helpboard_db
PGUSER=helpboard_user
PGPASSWORD=${db_password}

# OpenAI Configuration (MUST BE PROVIDED BY USER)
OPENAI_API_KEY=your_openai_api_key_here

# Session Configuration
SESSION_SECRET=${session_secret}

# Application Configuration
NODE_ENV=development
PORT=5000

# Domain Configuration
DOMAIN=helpboard.selfany.com
EOF
    
    log_success "Secure .env file generated with random passwords"
    log_warning "You MUST update the OPENAI_API_KEY in .env file"
}

# Show next steps
show_next_steps() {
    log_step "Setup phase completed successfully!"
    echo ""
    log_info "Next steps:"
    echo "1. Edit the .env file to add your OpenAI API key:"
    echo "   nano $DEPLOY_DIR/.env"
    echo ""
    echo "2. Update OPENAI_API_KEY with your actual key from OpenAI"
    echo ""
    echo "3. Ensure all application files are in $DEPLOY_DIR"
    echo ""
    echo "4. Run the deployment phase:"
    echo "   cd $DEPLOY_DIR && ./deployment-phase.sh"
    echo ""
    log_warning "DO NOT proceed to deployment until .env is properly configured!"
    echo ""
    log_info "Generated secure passwords are already in .env file"
    log_info "Domain configured for: $DOMAIN"
}

# Main execution
main() {
    log_info "Starting HelpBoard Setup Phase for Digital Ocean..."
    
    check_root
    verify_do_environment
    clean_previous_installation
    install_system_packages
    configure_git
    install_docker
    configure_firewall
    clone_repository
    create_env_template
    generate_secure_configs
    show_next_steps
    
    log_success "Setup phase completed!"
}

main