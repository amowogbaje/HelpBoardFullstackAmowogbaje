#!/bin/bash

# Digital Ocean Droplet Setup Script for HelpBoard
# Optimized for Ubuntu 22.04 LTS on Digital Ocean

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Ubuntu
check_os() {
    if [[ ! -f /etc/lsb-release ]] || ! grep -q "Ubuntu" /etc/lsb-release; then
        log_error "This script is designed for Ubuntu. Please use Ubuntu 22.04 LTS."
        exit 1
    fi
    log_info "Ubuntu detected - proceeding with setup"
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    apt update && apt upgrade -y
    apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release ufw fail2ban git build-essential
}

# Configure firewall for Digital Ocean
setup_firewall() {
    log_info "Configuring UFW firewall for Digital Ocean..."
    
    # Reset firewall rules
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH access (Digital Ocean requires this)
    ufw allow ssh
    ufw allow 22/tcp
    
    # HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Optional: Allow monitoring ports (comment out for production)
    # ufw allow 9090/tcp # Prometheus
    # ufw allow 3000/tcp # Grafana
    
    # Enable firewall
    ufw --force enable
    log_info "Firewall configured successfully"
}

# Configure fail2ban for additional security
setup_fail2ban() {
    log_info "Configuring fail2ban..."
    
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
EOF
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    log_info "fail2ban configured successfully"
}

# Install Docker for Digital Ocean
install_docker() {
    log_info "Installing Docker..."
    
    # Remove old Docker versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl enable docker
    systemctl start docker
    
    # Add current user to docker group
    usermod -aG docker ${SUDO_USER:-$USER}
    
    log_info "Docker installed successfully"
}

# Install Docker Compose standalone
install_docker_compose() {
    log_info "Installing Docker Compose..."
    
    # Get latest version
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    
    # Download and install
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for compatibility
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_info "Docker Compose installed successfully"
}

# Optimize Digital Ocean droplet for Docker
optimize_droplet() {
    log_info "Optimizing droplet for Docker workloads..."
    
    # Increase file descriptor limits
    cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    
    # Configure kernel parameters for better networking
    cat > /etc/sysctl.d/99-docker-optimization.conf << 'EOF'
# Network optimizations for Docker
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr

# Memory optimizations
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# File system optimizations
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
EOF
    
    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-docker-optimization.conf
    
    log_info "Droplet optimization completed"
}

# Setup swap for smaller droplets
setup_swap() {
    if [[ $(free -m | awk '/^Mem:/{print $2}') -lt 4096 ]]; then
        log_info "Setting up swap file for better performance..."
        
        # Create 2GB swap file
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        
        # Make swap permanent
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        
        # Optimize swap usage
        echo 'vm.swappiness=10' >> /etc/sysctl.conf
        
        log_info "Swap file created successfully"
    else
        log_info "Sufficient memory detected, skipping swap setup"
    fi
}

# Create application directory with proper permissions
setup_app_directory() {
    log_info "Setting up application directory..."
    
    APP_DIR="/opt/helpboard"
    mkdir -p "$APP_DIR"
    chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$APP_DIR"
    
    # Create necessary subdirectories
    mkdir -p "$APP_DIR"/{ssl,backups,logs,monitoring}
    
    log_info "Application directory created at $APP_DIR"
}

# Install monitoring tools
install_monitoring() {
    log_info "Installing monitoring tools..."
    
    # Install htop, iotop, and other monitoring tools
    apt install -y htop iotop nethogs ncdu tree jq
    
    # Install Docker stats tools
    docker pull google/cadvisor:latest
    docker pull prom/node-exporter:latest
    
    log_info "Monitoring tools installed"
}

# Configure log rotation for Docker
setup_log_rotation() {
    log_info "Configuring Docker log rotation..."
    
    cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "dns": ["8.8.8.8", "8.8.4.4"],
  "live-restore": true
}
EOF
    
    systemctl restart docker
    log_info "Docker log rotation configured"
}

# Setup automatic security updates
setup_auto_updates() {
    log_info "Configuring automatic security updates..."
    
    apt install -y unattended-upgrades
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    
    systemctl enable unattended-upgrades
    log_info "Automatic security updates configured"
}

# Main installation function
main() {
    log_info "Starting Digital Ocean droplet setup for HelpBoard..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    check_os
    update_system
    setup_firewall
    setup_fail2ban
    install_docker
    install_docker_compose
    optimize_droplet
    setup_swap
    setup_app_directory
    install_monitoring
    setup_log_rotation
    setup_auto_updates
    
    log_info "Digital Ocean droplet setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Logout and login again to apply docker group membership"
    echo "2. Clone your HelpBoard repository to /opt/helpboard"
    echo "3. Configure your .env file with production values"
    echo "4. Run the deployment script: ./deploy.sh init"
    echo
    log_warn "Remember to:"
    echo "- Configure your domain DNS to point to this droplet's IP"
    echo "- Set up SSL certificates with Let's Encrypt"
    echo "- Configure monitoring and alerting"
    echo "- Set up regular backups"
}

# Run main function
main "$@"