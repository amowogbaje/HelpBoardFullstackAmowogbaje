#!/bin/bash

# Docker-only HelpBoard deployment for DigitalOcean
# No Node.js installation required on host

set -e

echo "Starting Docker-only HelpBoard deployment..."

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    apt update && apt install -y docker-compose-plugin curl
fi

# Stop any existing containers
docker compose down 2>/dev/null || true
docker stop $(docker ps -q) 2>/dev/null || true

# Free up ports
fuser -k 80/tcp 443/tcp 2>/dev/null || true

# Create simple Dockerfile
cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package.json
COPY package.json .
RUN npm install

# Copy server file
COPY server.js .

# Create public directory
RUN mkdir -p public

EXPOSE 5000

CMD ["node", "server.js"]
EOF

# Create package.json
cat > package.json << 'EOF'
{
  "name": "helpboard",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Create server.js
cat > server.js << 'EOF'
const express = require('express');
const app = express();
const port = 5000;

app.use(express.json());
app.use(express.static('public'));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    platform: 'Docker',
    environment: 'production'
  });
});

// Basic API endpoints
app.get('/api/conversations', (req, res) => {
  res.json([
    {
      id: 1,
      customer: { name: 'Demo Customer', email: 'demo@example.com' },
      status: 'open',
      messageCount: 0,
      unreadCount: 0,
      createdAt: new Date().toISOString()
    }
  ]);
});

app.post('/api/initiate', (req, res) => {
  res.json({
    sessionId: 'demo-session-' + Math.random().toString(36).substr(2, 9),
    conversationId: Date.now(),
    message: 'HelpBoard Docker deployment successful'
  });
});

// Serve main page
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>HelpBoard - Docker Production</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
                background: #f8fafc; 
                color: #334155;
            }
            .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
            .header { 
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                color: white; 
                padding: 2rem; 
                border-radius: 12px; 
                margin-bottom: 2rem;
                text-align: center;
            }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
            .card { 
                background: white; 
                border-radius: 12px; 
                padding: 24px; 
                box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
                border: 1px solid #e2e8f0;
            }
            .status { 
                display: inline-flex; 
                align-items: center; 
                padding: 8px 16px; 
                border-radius: 20px; 
                font-size: 14px; 
                font-weight: 500;
                margin: 4px 0;
            }
            .status.success { background: #dcfce7; color: #166534; }
            .btn { 
                background: #3b82f6; 
                color: white; 
                border: none; 
                padding: 12px 24px; 
                border-radius: 8px; 
                cursor: pointer; 
                font-weight: 500;
                margin: 8px 8px 8px 0;
                transition: background-color 0.2s;
            }
            .btn:hover { background: #2563eb; }
            .endpoint { 
                background: #f1f5f9; 
                border: 1px solid #cbd5e1; 
                padding: 12px; 
                border-radius: 8px; 
                margin: 8px 0; 
                font-family: 'Monaco', 'Consolas', monospace;
                font-size: 14px;
            }
            .results { 
                background: #f8fafc; 
                border: 1px solid #e2e8f0; 
                padding: 16px; 
                border-radius: 8px; 
                margin-top: 16px; 
                white-space: pre-wrap; 
                font-family: 'Monaco', 'Consolas', monospace;
                font-size: 13px;
            }
            h1 { font-size: 2.5rem; margin-bottom: 0.5rem; }
            h2 { color: #1e293b; margin-bottom: 1rem; }
            h3 { color: #475569; margin-bottom: 0.75rem; }
            ul { margin-left: 1.5rem; }
            li { margin: 0.5rem 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 HelpBoard</h1>
                <p>AI-Powered Customer Support Platform - Docker Production</p>
            </div>
            
            <div class="grid">
                <div class="card">
                    <h2>System Status</h2>
                    <div class="status success">✅ Docker Container Running</div>
                    <div class="status success">✅ Express Server Active</div>
                    <div class="status success">✅ API Endpoints Ready</div>
                    <div class="status success">✅ Health Check Available</div>
                    
                    <h3>Quick Tests</h3>
                    <button class="btn" onclick="testHealth()">Health Check</button>
                    <button class="btn" onclick="testAPI()">Test API</button>
                    <button class="btn" onclick="initSession()">Init Session</button>
                </div>
                
                <div class="card">
                    <h2>Available Endpoints</h2>
                    <div class="endpoint">GET /api/health</div>
                    <div class="endpoint">GET /api/conversations</div>
                    <div class="endpoint">POST /api/initiate</div>
                    
                    <h3>Next Steps</h3>
                    <ul>
                        <li>Deploy full HelpBoard application</li>
                        <li>Configure PostgreSQL database</li>
                        <li>Add AI integration</li>
                        <li>Set up WebSocket communication</li>
                        <li>Configure SSL certificates</li>
                    </ul>
                </div>
            </div>
            
            <div class="card">
                <h2>Test Results</h2>
                <div id="results" class="results">Click buttons above to test the API endpoints</div>
            </div>
        </div>

        <script>
            async function testHealth() {
                try {
                    const response = await fetch('/api/health');
                    const data = await response.json();
                    document.getElementById('results').textContent = 
                        'Health Check Result:\\n' + JSON.stringify(data, null, 2);
                } catch (error) {
                    document.getElementById('results').textContent = 'Error: ' + error.message;
                }
            }
            
            async function testAPI() {
                try {
                    const response = await fetch('/api/conversations');
                    const data = await response.json();
                    document.getElementById('results').textContent = 
                        'Conversations API Result:\\n' + JSON.stringify(data, null, 2);
                } catch (error) {
                    document.getElementById('results').textContent = 'Error: ' + error.message;
                }
            }
            
            async function initSession() {
                try {
                    const response = await fetch('/api/initiate', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ name: 'Test Customer' })
                    });
                    const data = await response.json();
                    document.getElementById('results').textContent = 
                        'Session Initiation Result:\\n' + JSON.stringify(data, null, 2);
                } catch (error) {
                    document.getElementById('results').textContent = 'Error: ' + error.message;
                }
            }
        </script>
    </body>
    </html>
  `);
});

app.listen(port, '0.0.0.0', () => {
  console.log(\`HelpBoard Docker server running on port \${port}\`);
  console.log(\`Container started at \${new Date().toISOString()}\`);
});
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    ports:
      - "5000:5000"
      - "8080:5000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  app_data:
EOF

echo "Building Docker container..."
docker compose build --no-cache

echo "Starting HelpBoard container..."
docker compose up -d

# Wait for container to start
sleep 10

# Test the deployment
echo "Testing deployment..."
if curl -f -s http://localhost:5000/api/health > /dev/null; then
    echo "✅ HelpBoard deployed successfully!"
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    echo "🌐 Access your platform at:"
    echo "   - http://$SERVER_IP:5000"
    echo "   - http://$SERVER_IP:8080 (alternative port)"
    echo "🏥 Health check: http://$SERVER_IP:5000/api/health"
else
    echo "❌ Deployment failed. Checking logs..."
    docker compose logs app
fi

echo ""
echo "Container status:"
docker compose ps

echo ""
echo "To view logs: docker compose logs app"
echo "To restart: docker compose restart"
echo "To stop: docker compose down"