# HelpBoard Deployment Guide for DigitalOcean

This guide will walk you through deploying your HelpBoard customer support platform to a DigitalOcean droplet using Docker.

## Prerequisites

- DigitalOcean account
- Domain name (optional but recommended)
- OpenAI API key
- Basic knowledge of terminal/command line

## Step 1: Create DigitalOcean Droplet

1. **Log into DigitalOcean Console**
   - Go to https://cloud.digitalocean.com
   - Click "Create" → "Droplets"

2. **Configure Droplet**
   - **Image**: Ubuntu 22.04 LTS
   - **Plan**: Basic ($24/month, 4GB RAM, 2 vCPUs, 80GB SSD)
   - **Authentication**: SSH Keys (recommended) or Password
   - **Hostname**: helpboard-production
   - **Tags**: helpboard, production

3. **Create Droplet**
   - Click "Create Droplet"
   - Note the IP address once created

## Step 2: Initial Server Setup

1. **Connect to Your Droplet**
   ```bash
   ssh root@YOUR_DROPLET_IP
   ```

2. **Update System**
   ```bash
   apt update && apt upgrade -y
   ```

3. **Install Docker and Docker Compose**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # Install Docker Compose
   curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   chmod +x /usr/local/bin/docker-compose
   
   # Verify installation
   docker --version
   docker-compose --version
   ```

4. **Create Application Directory**
   ```bash
   mkdir -p /opt/helpboard
   cd /opt/helpboard
   ```

## Step 3: Upload Application Files

1. **Transfer Files to Server**
   From your local machine, upload the project files:
   ```bash
   # Option 1: Using SCP
   scp -r . root@YOUR_DROPLET_IP:/opt/helpboard/
   
   # Option 2: Using Git (if you have a repository)
   git clone YOUR_REPOSITORY_URL /opt/helpboard
   ```

2. **Set Correct Permissions**
   ```bash
   chmod +x /opt/helpboard/deploy.sh
   ```

## Step 4: Configure Environment

1. **Create Environment File**
   ```bash
   cd /opt/helpboard
   cp .env.example .env
   nano .env
   ```

2. **Configure Environment Variables**
   ```env
   # Database Configuration
   DATABASE_URL=postgresql://helpboard:your_secure_password@postgres:5432/helpboard
   POSTGRES_PASSWORD=your_secure_password_here
   
   # OpenAI API Key (Get from https://platform.openai.com/api-keys)
   OPENAI_API_KEY=sk-your-openai-api-key-here
   
   # Application Settings
   NODE_ENV=production
   PORT=5000
   
   # Session Security
   SESSION_SECRET=your-random-session-secret-here
   ```

   **Generate secure passwords:**
   ```bash
   # Generate secure database password
   openssl rand -base64 32
   
   # Generate session secret
   openssl rand -hex 64
   ```

## Step 5: SSL Certificate Setup (HTTPS)

1. **Create SSL Directory**
   ```bash
   mkdir -p /opt/helpboard/ssl
   ```

2. **Option A: Self-Signed Certificate (Development/Testing)**
   ```bash
   cd /opt/helpboard/ssl
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout key.pem -out cert.pem \
     -subj "/C=US/ST=State/L=City/O=Organization/CN=your-domain.com"
   ```

3. **Option B: Let's Encrypt Certificate (Production)**
   ```bash
   # Install Certbot
   apt install certbot -y
   
   # Stop any running services on port 80
   docker-compose down
   
   # Get certificate
   certbot certonly --standalone -d your-domain.com
   
   # Copy certificates
   cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /opt/helpboard/ssl/cert.pem
   cp /etc/letsencrypt/live/your-domain.com/privkey.pem /opt/helpboard/ssl/key.pem
   ```

## Step 6: Deploy Application

1. **Run Deployment Script**
   ```bash
   cd /opt/helpboard
   ./deploy.sh
   ```

2. **Verify Deployment**
   ```bash
   # Check running containers
   docker-compose ps
   
   # Check logs
   docker-compose logs -f
   
   # Test application
   curl -k https://localhost/api/health
   ```

## Step 7: Configure Firewall

1. **Set Up UFW Firewall**
   ```bash
   # Enable UFW
   ufw enable
   
   # Allow SSH
   ufw allow ssh
   
   # Allow HTTP and HTTPS
   ufw allow 80
   ufw allow 443
   
   # Check status
   ufw status
   ```

## Step 8: Domain Configuration (Optional)

1. **Configure DNS Records**
   In your domain registrar's DNS settings:
   - **A Record**: Point your domain to your droplet's IP address
   - **CNAME Record**: Point www.yourdomain.com to yourdomain.com

2. **Update Nginx Configuration**
   ```bash
   nano /opt/helpboard/nginx.conf
   ```
   
   Replace `server_name _;` with `server_name yourdomain.com www.yourdomain.com;`

3. **Restart Services**
   ```bash
   docker-compose restart nginx
   ```

## Step 9: Set Up Automatic Updates

1. **Create Update Script**
   ```bash
   cat > /opt/helpboard/update.sh << 'EOF'
   #!/bin/bash
   cd /opt/helpboard
   git pull origin main
   docker-compose build --no-cache
   docker-compose up -d
   EOF
   
   chmod +x /opt/helpboard/update.sh
   ```

2. **Set Up Automatic Backups**
   ```bash
   cat > /opt/helpboard/backup.sh << 'EOF'
   #!/bin/bash
   BACKUP_DIR="/opt/backups/helpboard"
   DATE=$(date +%Y%m%d_%H%M%S)
   
   mkdir -p $BACKUP_DIR
   
   # Backup database
   docker-compose exec -T postgres pg_dump -U helpboard helpboard > $BACKUP_DIR/db_backup_$DATE.sql
   
   # Keep only last 7 days of backups
   find $BACKUP_DIR -name "db_backup_*.sql" -mtime +7 -delete
   EOF
   
   chmod +x /opt/helpboard/backup.sh
   ```

3. **Set Up Cron Jobs**
   ```bash
   crontab -e
   ```
   
   Add these lines:
   ```cron
   # Backup database daily at 2 AM
   0 2 * * * /opt/helpboard/backup.sh
   
   # Renew SSL certificates (if using Let's Encrypt)
   0 12 * * * /usr/bin/certbot renew --quiet && docker-compose restart nginx
   ```

## Step 10: Monitoring and Maintenance

1. **Monitor Application Health**
   ```bash
   # Check container status
   docker-compose ps
   
   # Monitor resource usage
   docker stats
   
   # View application logs
   docker-compose logs -f app
   ```

2. **Common Commands**
   ```bash
   # Restart all services
   docker-compose restart
   
   # Update application
   ./update.sh
   
   # View database logs
   docker-compose logs postgres
   
   # Access database directly
   docker-compose exec postgres psql -U helpboard -d helpboard
   ```

## Security Best Practices

1. **Change Default Passwords**
   - Update all default passwords in the `.env` file
   - Use strong, unique passwords

2. **Keep System Updated**
   ```bash
   # Regular system updates
   apt update && apt upgrade -y
   
   # Update Docker images
   docker-compose pull
   docker-compose up -d
   ```

3. **Monitor Logs**
   ```bash
   # Check for suspicious activity
   tail -f /var/log/auth.log
   
   # Monitor application logs
   docker-compose logs -f
   ```

## Troubleshooting

### Common Issues

1. **Database Connection Error**
   ```bash
   # Check database container
   docker-compose logs postgres
   
   # Verify environment variables
   cat .env
   ```

2. **SSL Certificate Issues**
   ```bash
   # Check certificate files
   ls -la ssl/
   
   # Test SSL
   openssl x509 -in ssl/cert.pem -text -noout
   ```

3. **Application Won't Start**
   ```bash
   # Check application logs
   docker-compose logs app
   
   # Rebuild containers
   docker-compose build --no-cache
   docker-compose up -d
   ```

### Performance Optimization

1. **Enable Docker Logging Driver**
   ```bash
   # Add to docker-compose.yml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

2. **Monitor Resource Usage**
   ```bash
   # Install monitoring tools
   apt install htop iotop -y
   
   # Monitor Docker resources
   docker stats --no-stream
   ```

## Support

For additional support:
- Check application logs: `docker-compose logs -f`
- Monitor system resources: `htop`
- Review this deployment guide
- Contact system administrator

## Next Steps

1. **Access Your Application**
   - Navigate to `https://your-domain.com` or `https://YOUR_DROPLET_IP`
   - Log in with the default credentials (as configured in your application)

2. **Configure Your Support System**
   - Set up agent accounts
   - Configure AI training data
   - Customize chat widget for your website

3. **Monitor and Maintain**
   - Set up regular backups
   - Monitor application performance
   - Keep system updated

Your HelpBoard customer support platform is now deployed and ready for production use!