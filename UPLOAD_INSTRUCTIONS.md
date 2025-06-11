# Upload Instructions for DigitalOcean Deployment

## Method 1: Direct File Upload (Recommended)

From your local machine where you have the project files:

```bash
# Create deployment package
tar -czf helpboard-deployment.tar.gz \
  --exclude=node_modules \
  --exclude=.git \
  --exclude=.cache \
  --exclude=dist \
  .

# Upload to your droplet
scp helpboard-deployment.tar.gz root@YOUR_DROPLET_IP:/opt/

# SSH into droplet
ssh root@YOUR_DROPLET_IP

# Extract files
cd /opt
tar -xzf helpboard-deployment.tar.gz -C helpboard/
cd helpboard

# Set permissions
chmod +x deploy.sh quick-fix.sh
```

## Method 2: Direct Commands on Droplet

If you're already on your droplet, run these commands:

```bash
cd /opt/helpboard

# Create all required files directly
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://helpboard:helpboard123@postgres:5432/helpboard
POSTGRES_DB=helpboard
POSTGRES_USER=helpboard
POSTGRES_PASSWORD=helpboard123
OPENAI_API_KEY=your_openai_api_key_here
EOF

# Test application availability
curl -f http://localhost:5000/api/health

# If application not running, start deployment
./deploy.sh
```

## Method 3: Git Clone (If Repository Available)

```bash
cd /opt
git clone YOUR_REPOSITORY_URL helpboard
cd helpboard
chmod +x deploy.sh
./deploy.sh
```

## Next Steps After Upload

1. **Run deployment script:**
   ```bash
   cd /opt/helpboard
   ./deploy.sh
   ```

2. **Check deployment status:**
   ```bash
   docker compose ps
   curl http://localhost:5000/api/health
   ```

3. **Configure SSL (Optional):**
   ```bash
   certbot --nginx -d yourdomain.com
   ```

Your HelpBoard platform will be accessible at:
- HTTP: `http://YOUR_DROPLET_IP`
- HTTPS: `https://YOUR_DROPLET_IP` (after SSL setup)
- Health check: `http://YOUR_DROPLET_IP/api/health`