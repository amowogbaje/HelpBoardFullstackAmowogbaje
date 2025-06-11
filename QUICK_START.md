# HelpBoard Quick Deployment Guide

## Option 1: Automated Setup (Recommended)

1. **Create DigitalOcean Droplet**
   - Ubuntu 22.04 LTS
   - 4GB RAM, 2 vCPUs minimum
   - Add SSH key or password

2. **Run Automated Setup**
   ```bash
   ssh root@YOUR_DROPLET_IP
   curl -sSL https://raw.githubusercontent.com/your-repo/helpboard/main/production-setup.sh | bash
   ```

3. **Configure Application**
   ```bash
   cd /opt/helpboard
   nano .env  # Add your OpenAI API key
   ```

4. **Upload and Deploy**
   ```bash
   # Upload your files to /opt/helpboard
   ./deploy.sh
   ```

## Option 2: Manual Setup

### Prerequisites on DigitalOcean Droplet
```bash
# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### Deployment Steps
```bash
# Create directory
mkdir -p /opt/helpboard
cd /opt/helpboard

# Copy your project files here
# Configure environment
cp .env.example .env
nano .env

# Deploy
./deploy.sh
```

## Configuration

### Required Environment Variables
```env
DATABASE_URL=postgresql://helpboard:secure_password@postgres:5432/helpboard
POSTGRES_PASSWORD=secure_password
OPENAI_API_KEY=sk-your-openai-api-key
NODE_ENV=production
PORT=5000
```

### SSL Certificate (Production)
```bash
# Install Certbot
apt install certbot -y

# Get certificate
certbot certonly --standalone -d yourdomain.com

# Copy to SSL directory
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem /opt/helpboard/ssl/cert.pem
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem /opt/helpboard/ssl/key.pem

# Restart services
docker-compose restart nginx
```

## Monitoring

### Health Check
```bash
curl https://your-domain.com/api/health
```

### View Logs
```bash
cd /opt/helpboard
docker-compose logs -f
```

### System Status
```bash
./monitor.sh
```

## Maintenance

### Backup Database
```bash
./backup.sh
```

### Update Application
```bash
./update.sh
```

### Restart Services
```bash
docker-compose restart
```

## Troubleshooting

### Container Issues
```bash
docker-compose ps
docker-compose logs app
```

### Database Issues
```bash
docker-compose logs postgres
docker-compose exec postgres psql -U helpboard -d helpboard
```

### SSL Issues
```bash
openssl x509 -in ssl/cert.pem -text -noout
```

Your HelpBoard platform will be available at `https://your-domain.com` or `https://your-droplet-ip`