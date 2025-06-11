#!/bin/bash

# HelpBoard Production Setup Script
# Run this script on your DigitalOcean droplet to set up the complete environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 HelpBoard Production Setup${NC}"
echo "This script will set up your complete production environment"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (use sudo)"
    exit 1
fi

print_status "Starting system setup..."

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y
print_status "System updated"

# Install required packages
echo "🔧 Installing required packages..."
apt install -y curl wget git ufw htop nano openssl certbot

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    print_status "Docker installed"
else
    print_status "Docker already installed"
fi

# Install Docker Compose
echo "📦 Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    print_status "Docker Compose installed"
else
    print_status "Docker Compose already installed"
fi

# Start and enable Docker
systemctl start docker
systemctl enable docker
print_status "Docker service configured"

# Create application directory
APP_DIR="/opt/helpboard"
echo "📁 Creating application directory..."
mkdir -p $APP_DIR
cd $APP_DIR

# Set up firewall
echo "🔥 Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
print_status "Firewall configured"

# Create SSL directory
mkdir -p $APP_DIR/ssl

# Generate environment file if it doesn't exist
if [ ! -f "$APP_DIR/.env" ]; then
    echo "⚙️  Creating environment configuration..."
    
    # Generate secure passwords
    DB_PASSWORD=$(openssl rand -base64 32)
    SESSION_SECRET=$(openssl rand -hex 64)
    
    cat > $APP_DIR/.env << EOF
# Database Configuration
DATABASE_URL=postgresql://helpboard:${DB_PASSWORD}@postgres:5432/helpboard
POSTGRES_PASSWORD=${DB_PASSWORD}

# OpenAI API Key (You need to add this manually)
OPENAI_API_KEY=your_openai_api_key_here

# Application Settings
NODE_ENV=production
PORT=5000

# Session Security
SESSION_SECRET=${SESSION_SECRET}
EOF
    print_status "Environment file created"
    print_warning "Please edit .env file and add your OpenAI API key"
else
    print_status "Environment file already exists"
fi

# Create backup directory and scripts
echo "💾 Setting up backup system..."
mkdir -p /opt/backups/helpboard

cat > $APP_DIR/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/helpboard"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T postgres pg_dump -U helpboard helpboard > $BACKUP_DIR/db_backup_$DATE.sql

# Compress backup
gzip $BACKUP_DIR/db_backup_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "db_backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: db_backup_$DATE.sql.gz"
EOF

chmod +x $APP_DIR/backup.sh
print_status "Backup system configured"

# Create update script
cat > $APP_DIR/update.sh << 'EOF'
#!/bin/bash
cd /opt/helpboard

echo "🔄 Updating HelpBoard..."

# Pull latest changes (if using git)
if [ -d ".git" ]; then
    git pull origin main
fi

# Rebuild and restart containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d

echo "✅ Update completed"
EOF

chmod +x $APP_DIR/update.sh
print_status "Update script created"

# Set up log rotation
cat > /etc/logrotate.d/helpboard << 'EOF'
/opt/helpboard/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker-compose -f /opt/helpboard/docker-compose.yml restart nginx
    endscript
}
EOF

print_status "Log rotation configured"

# Create monitoring script
cat > $APP_DIR/monitor.sh << 'EOF'
#!/bin/bash
cd /opt/helpboard

echo "📊 HelpBoard System Status"
echo "=========================="

echo "🐳 Docker Containers:"
docker-compose ps

echo ""
echo "💾 Disk Usage:"
df -h

echo ""
echo "🧠 Memory Usage:"
free -h

echo ""
echo "⚡ CPU Usage:"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU Usage: " 100 - $1 "%"}'

echo ""
echo "🌐 Application Health:"
curl -s http://localhost:5000/api/health | head -1

echo ""
echo "📋 Recent Logs (last 10 lines):"
docker-compose logs --tail=10 app
EOF

chmod +x $APP_DIR/monitor.sh
print_status "Monitoring script created"

# Set up cron jobs
echo "⏰ Setting up automated tasks..."
(crontab -l 2>/dev/null; echo "0 2 * * * $APP_DIR/backup.sh >> /var/log/helpboard-backup.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && cd $APP_DIR && docker-compose restart nginx") | crontab -
print_status "Automated tasks configured"

# Create SSL certificate (self-signed for now)
if [ ! -f "$APP_DIR/ssl/cert.pem" ]; then
    echo "🔒 Creating self-signed SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout $APP_DIR/ssl/key.pem \
        -out $APP_DIR/ssl/cert.pem \
        -subj "/C=US/ST=State/L=City/O=HelpBoard/CN=localhost"
    print_status "SSL certificate created"
    print_warning "Using self-signed certificate. For production, use Let's Encrypt"
fi

# Set proper permissions
chown -R root:root $APP_DIR
chmod -R 755 $APP_DIR
chmod 600 $APP_DIR/.env
chmod 600 $APP_DIR/ssl/key.pem

print_status "Permissions set"

# Display summary
echo ""
echo -e "${BLUE}🎉 Setup Complete!${NC}"
echo "=================="
echo ""
echo "Next steps:"
echo "1. Edit $APP_DIR/.env and add your OpenAI API key"
echo "2. Upload your application files to $APP_DIR"
echo "3. Run: cd $APP_DIR && ./deploy.sh"
echo ""
echo "Useful commands:"
echo "• Monitor system: $APP_DIR/monitor.sh"
echo "• Update application: $APP_DIR/update.sh"
echo "• Create backup: $APP_DIR/backup.sh"
echo "• View logs: cd $APP_DIR && docker-compose logs -f"
echo ""
echo "Your HelpBoard will be available at: https://YOUR_SERVER_IP"
echo ""
print_warning "Remember to:"
print_warning "• Add your OpenAI API key to .env"
print_warning "• Configure your domain DNS (if using custom domain)"
print_warning "• Set up Let's Encrypt for production SSL"
echo ""