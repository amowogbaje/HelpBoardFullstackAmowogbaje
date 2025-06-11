#!/bin/bash

# Quick start script for DigitalOcean droplet
# This creates a minimal working HelpBoard deployment

echo "Setting up HelpBoard on DigitalOcean droplet..."

# Stop any existing processes
docker compose down 2>/dev/null || true
pkill -f node 2>/dev/null || true

# Install Docker if needed
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose
if ! docker compose version &> /dev/null; then
    apt update && apt install -y docker-compose-plugin
fi

# Create minimal package.json
cat > package.json << 'EOF'
{
  "name": "helpboard",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Create simple server
cat > server.js << 'EOF'
const express = require('express');
const app = express();
const port = 5000;

app.use(express.json());
app.use(express.static('public'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    platform: 'HelpBoard Production'
  });
});

// Basic endpoints
app.get('/api/conversations', (req, res) => {
  res.json([{
    id: 1,
    customer: { name: 'Demo Customer' },
    status: 'open',
    messageCount: 0
  }]);
});

app.post('/api/initiate', (req, res) => {
  res.json({
    sessionId: 'demo-session',
    conversationId: 1,
    message: 'HelpBoard is ready for deployment'
  });
});

// Serve basic frontend
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>HelpBoard - Production Ready</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
            .status { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 15px; border-radius: 5px; margin: 20px 0; }
            .api { background: #f8f9fa; border: 1px solid #dee2e6; padding: 15px; border-radius: 5px; margin: 10px 0; }
            button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin: 5px; }
            button:hover { background: #0056b3; }
        </style>
    </head>
    <body>
        <h1>🚀 HelpBoard - Production Deployment</h1>
        <div class="status">
            ✅ Platform successfully deployed and running on port ${port}
        </div>
        
        <h2>System Status</h2>
        <button onclick="testHealth()">Test Health Check</button>
        <button onclick="testAPI()">Test API</button>
        
        <div id="results"></div>
        
        <h2>Available API Endpoints</h2>
        <div class="api"><strong>GET</strong> /api/health - System health check</div>
        <div class="api"><strong>GET</strong> /api/conversations - List conversations</div>
        <div class="api"><strong>POST</strong> /api/initiate - Start customer session</div>
        
        <h2>Next Steps</h2>
        <ol>
            <li>Upload complete HelpBoard source files</li>
            <li>Configure database connection</li>
            <li>Set up AI integration with OpenAI API key</li>
            <li>Enable SSL with Let's Encrypt</li>
        </ol>
        
        <script>
            async function testHealth() {
                try {
                    const response = await fetch('/api/health');
                    const data = await response.json();
                    document.getElementById('results').innerHTML = 
                        '<h3>Health Check Result:</h3><pre>' + JSON.stringify(data, null, 2) + '</pre>';
                } catch (error) {
                    document.getElementById('results').innerHTML = 
                        '<h3>Error:</h3><p>' + error.message + '</p>';
                }
            }
            
            async function testAPI() {
                try {
                    const response = await fetch('/api/conversations');
                    const data = await response.json();
                    document.getElementById('results').innerHTML = 
                        '<h3>API Test Result:</h3><pre>' + JSON.stringify(data, null, 2) + '</pre>';
                } catch (error) {
                    document.getElementById('results').innerHTML = 
                        '<h3>Error:</h3><p>' + error.message + '</p>';
                }
            }
        </script>
    </body>
    </html>
  `);
});

app.listen(port, '0.0.0.0', () => {
  console.log(`HelpBoard server running on port ${port}`);
  console.log(`Access: http://localhost:${port}`);
});
EOF

# Create public directory
mkdir -p public

# Install dependencies and start
npm install

echo "Starting HelpBoard server..."
npm start &

# Wait for server to start
sleep 5

# Test the server
if curl -f http://localhost:5000/api/health >/dev/null 2>&1; then
    echo "✅ HelpBoard server started successfully!"
    echo "🌐 Access your platform at: http://$(curl -s ifconfig.me):5000"
    echo "🏥 Health check: http://$(curl -s ifconfig.me):5000/api/health"
else
    echo "❌ Server failed to start. Check logs:"
    tail -20 nohup.out 2>/dev/null || echo "No log file found"
fi

# Show running processes
echo "Running processes:"
ps aux | grep node || echo "No Node processes found"