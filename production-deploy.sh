#!/bin/bash

# Production HelpBoard Deployment with Monitoring & Rollback
# Combines troubleshooting, deployment, and monitoring

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOYMENT_LOG="/var/log/helpboard-deployment.log"
BACKUP_DIR="/opt/helpboard-backup"

log() {
    echo -e "$1" | tee -a "$DEPLOYMENT_LOG"
}

log "${BLUE}Starting HelpBoard Production Deployment...${NC}"
log "Timestamp: $(date)"

# Create backup
mkdir -p "$BACKUP_DIR"
if [ -f "docker-compose.yml" ]; then
    cp -r . "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)/"
    log "${GREEN}Backup created${NC}"
fi

# Run troubleshooter first
if [ -f "deployment-troubleshooter.sh" ]; then
    log "${YELLOW}Running system checks...${NC}"
    chmod +x deployment-troubleshooter.sh
    ./deployment-troubleshooter.sh >> "$DEPLOYMENT_LOG" 2>&1
else
    log "${YELLOW}Troubleshooter not found, running basic checks...${NC}"
    
    # Basic Docker check
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
    fi
    
    if ! docker compose version &> /dev/null; then
        log "Installing Docker Compose..."
        apt update && apt install -y docker-compose-plugin
    fi
fi

# Deploy with monitoring
log "${YELLOW}Starting deployment...${NC}"

# Build and deploy
docker compose build --no-cache 2>&1 | tee -a "$DEPLOYMENT_LOG"
docker compose up -d 2>&1 | tee -a "$DEPLOYMENT_LOG"

# Wait and monitor startup
log "${YELLOW}Monitoring startup...${NC}"
STARTUP_TIMEOUT=60
HEALTH_CHECK_COUNT=0
MAX_HEALTH_CHECKS=12

while [ $HEALTH_CHECK_COUNT -lt $MAX_HEALTH_CHECKS ]; do
    sleep 5
    
    if curl -f -s http://localhost:5000/api/health > /dev/null 2>&1; then
        log "${GREEN}Health check passed${NC}"
        break
    else
        HEALTH_CHECK_COUNT=$((HEALTH_CHECK_COUNT + 1))
        log "Health check attempt $HEALTH_CHECK_COUNT/$MAX_HEALTH_CHECKS"
        
        if [ $HEALTH_CHECK_COUNT -eq $MAX_HEALTH_CHECKS ]; then
            log "${RED}Deployment failed - health checks timeout${NC}"
            log "Container logs:"
            docker compose logs app | tail -20 | tee -a "$DEPLOYMENT_LOG"
            
            # Rollback option
            echo "Would you like to rollback? (y/n)"
            read -t 30 -r rollback_choice
            if [[ $rollback_choice =~ ^[Yy]$ ]]; then
                log "Rolling back..."
                docker compose down
                if [ -d "$BACKUP_DIR" ]; then
                    LATEST_BACKUP=$(ls -1t "$BACKUP_DIR" | head -1)
                    if [ -n "$LATEST_BACKUP" ]; then
                        cp -r "$BACKUP_DIR/$LATEST_BACKUP/"* .
                        docker compose up -d
                    fi
                fi
            fi
            exit 1
        fi
    fi
done

# Final verification
log "${YELLOW}Running final verification...${NC}"

# Test all endpoints
ENDPOINTS=("/api/health" "/api/conversations" "/")
for endpoint in "${ENDPOINTS[@]}"; do
    if curl -f -s "http://localhost:5000$endpoint" > /dev/null; then
        log "${GREEN}✅ $endpoint working${NC}"
    else
        log "${RED}❌ $endpoint failed${NC}"
    fi
done

# Get server info
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "Unknown")

# Generate deployment report
cat > deployment-report.txt << EOF
HelpBoard Deployment Report
===========================
Date: $(date)
Server IP: $SERVER_IP
Status: Successful

Access URLs:
- Main: http://$SERVER_IP:5000
- Alternative: http://$SERVER_IP:8080
- Health: http://$SERVER_IP:5000/api/health

Container Status:
$(docker compose ps)

Health Check:
$(curl -s http://localhost:5000/api/health 2>/dev/null || echo "Health check failed")

Logs Location: $DEPLOYMENT_LOG
Backup Location: $BACKUP_DIR

Next Steps:
1. Configure SSL certificates
2. Set up domain DNS
3. Deploy full HelpBoard features
4. Configure monitoring alerts
EOF

log "${GREEN}Deployment completed successfully!${NC}"
log "Report saved to: deployment-report.txt"
log "Access your platform at: http://$SERVER_IP:5000"

# Set up basic monitoring
cat > monitor.sh << 'EOF'
#!/bin/bash
# Basic monitoring script

while true; do
    if ! curl -f -s http://localhost:5000/api/health > /dev/null; then
        echo "$(date): Health check failed, attempting restart"
        docker compose restart app
        sleep 30
    fi
    sleep 60
done
EOF

chmod +x monitor.sh
nohup ./monitor.sh > monitor.log 2>&1 &

log "Monitoring started in background (PID: $!)"
log "View logs: tail -f monitor.log"