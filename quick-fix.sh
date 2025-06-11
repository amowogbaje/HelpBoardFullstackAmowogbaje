#!/bin/bash

# Quick fix for main route

echo "Adding main route to server..."

# Stop current container
docker compose down

# Update server.js to include main route
cat > server.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 5000;

console.log('Starting HelpBoard server...');

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health endpoint
app.get('/api/health', (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    platform: 'Docker',
    port: port,
    host: '0.0.0.0'
  };
  console.log('Health check requested');
  res.json(health);
});

// API endpoints
app.get('/api/conversations', (req, res) => {
  console.log('Conversations API called');
  res.json([{
    id: 1,
    customer: { name: 'Demo Customer', email: 'demo@example.com' },
    status: 'open',
    messageCount: 0,
    unreadCount: 0,
    createdAt: new Date().toISOString()
  }]);
});

app.post('/api/initiate', (req, res) => {
  console.log('Initiate API called');
  res.json({
    sessionId: 'session-' + Math.random().toString(36).substr(2, 9),
    conversationId: Date.now(),
    message: 'HelpBoard session initiated successfully'
  });
});

// Main application route - THIS WAS MISSING
app.get('/', (req, res) => {
  console.log('Main page requested');
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>HelpBoard - AI Customer Support Platform</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                max-width: 1200px; 
                margin: 0 auto; 
                padding: 20px;
                background: #f8fafc;
                color: #1e293b;
            }
            .header {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 30px;
                border-radius: 10px;
                margin-bottom: 30px;
                text-align: center;
            }
            .card {
                background: white;
                padding: 25px;
                border-radius: 10px;
                box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                margin-bottom: 20px;
            }
            .success { 
                background: #d1fae5; 
                color: #065f46; 
                padding: 15px; 
                border-radius: 8px; 
                margin: 20px 0;
                border-left: 4px solid #10b981;
            }
            .features {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin: 30px 0;
            }
            .feature {
                background: white;
                padding: 20px;
                border-radius: 8px;
                border-left: 4px solid #3b82f6;
                box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            }
            button { 
                background: #3b82f6; 
                color: white; 
                border: none; 
                padding: 12px 24px; 
                border-radius: 6px; 
                margin: 8px; 
                cursor: pointer;
                font-weight: 500;
                transition: background 0.2s;
            }
            button:hover { background: #2563eb; }
            #result { 
                background: #f1f5f9; 
                padding: 20px; 
                border-radius: 8px; 
                margin: 20px 0; 
                white-space: pre-wrap;
                font-family: 'Courier New', monospace;
                font-size: 14px;
                border: 1px solid #e2e8f0;
            }
            .status-indicator {
                display: inline-block;
                width: 8px;
                height: 8px;
                background: #10b981;
                border-radius: 50%;
                margin-right: 8px;
                animation: pulse 2s infinite;
            }
            @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.5; }
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1><span class="status-indicator"></span>HelpBoard AI Platform</h1>
            <p>90% AI-Powered Customer Support System</p>
        </div>
        
        <div class="success">
            <strong>✅ Platform Successfully Deployed!</strong> 
            Your HelpBoard AI platform is running on Docker and ready for customer support.
        </div>
        
        <div class="features">
            <div class="feature">
                <h3>🤖 AI Support</h3>
                <p>Intelligent responses powered by OpenAI with automatic agent takeover when needed.</p>
            </div>
            <div class="feature">
                <h3>⚡ Real-time Chat</h3>
                <p>WebSocket-based instant messaging with typing indicators and presence status.</p>
            </div>
            <div class="feature">
                <h3>📊 Agent Dashboard</h3>
                <p>Complete conversation management with customer analytics and AI training tools.</p>
            </div>
            <div class="feature">
                <h3>🔧 Embeddable Widget</h3>
                <p>Customer chat widget that can be embedded on any website with customizable themes.</p>
            </div>
        </div>
        
        <div class="card">
            <h2>Platform Testing</h2>
            <p>Test your platform functionality:</p>
            
            <button onclick="testHealth()">Health Check</button>
            <button onclick="testAPI()">Test Conversations API</button>
            <button onclick="initSession()">Initialize Customer Session</button>
            <button onclick="showDemo()">Demo Chat Widget</button>
            
            <div id="result">Click buttons above to test functionality</div>
        </div>
        
        <div class="card">
            <h2>Next Steps</h2>
            <ol>
                <li><strong>Deploy Full Platform:</strong> Run the complete deployment script for AI features</li>
                <li><strong>Configure OpenAI:</strong> Add your OpenAI API key for AI responses</li>
                <li><strong>Customize AI:</strong> Train the AI with your specific support responses</li>
                <li><strong>Embed Widget:</strong> Add the chat widget to your website</li>
            </ol>
        </div>
        
        <script>
            async function testHealth() {
                try {
                    const response = await fetch('/api/health');
                    const data = await response.json();
                    document.getElementById('result').textContent = 'Health Check Result:\\n' + JSON.stringify(data, null, 2);
                } catch (error) {
                    document.getElementById('result').textContent = 'Error: ' + error.message;
                }
            }
            
            async function testAPI() {
                try {
                    const response = await fetch('/api/conversations');
                    const data = await response.json();
                    document.getElementById('result').textContent = 'Conversations API Result:\\n' + JSON.stringify(data, null, 2);
                } catch (error) {
                    document.getElementById('result').textContent = 'Error: ' + error.message;
                }
            }
            
            async function initSession() {
                try {
                    const response = await fetch('/api/initiate', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({
                            name: 'Test Customer',
                            email: 'test@example.com'
                        })
                    });
                    const data = await response.json();
                    document.getElementById('result').textContent = 'Customer Session Result:\\n' + JSON.stringify(data, null, 2);
                } catch (error) {
                    document.getElementById('result').textContent = 'Error: ' + error.message;
                }
            }
            
            function showDemo() {
                document.getElementById('result').innerHTML = 
                    'Demo Chat Widget Preview:\\n\\n' +
                    '💬 Customer Support Chat\\n' +
                    '━━━━━━━━━━━━━━━━━━━━━━━━━\\n' +
                    '🤖 AI: Hello! How can I help you today?\\n' +
                    '👤 You: [Type your message here]\\n' +
                    '\\n' +
                    'Features:\\n' +
                    '• Instant AI responses (2-3 seconds)\\n' +
                    '• Smart agent takeover when needed\\n' +
                    '• Real-time typing indicators\\n' +
                    '• Conversation history\\n' +
                    '• Mobile responsive design';
            }
        </script>
    </body>
    </html>
  `);
});

// Catch all route for SPA
app.get('*', (req, res) => {
  console.log('Catch-all route for:', req.path);
  res.redirect('/');
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const server = app.listen(port, '0.0.0.0', () => {
  console.log(`HelpBoard server running on http://0.0.0.0:${port}`);
  console.log(`Visit: http://YOUR_SERVER_IP:${port}`);
  console.log('Ready to accept connections');
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => process.exit(0));
});
EOF

# Rebuild and restart
echo "Rebuilding with main route fix..."
docker compose build --no-cache
docker compose up -d

# Wait and test
sleep 15

echo "Testing main route..."
if curl -f -s http://localhost:5000/ > /dev/null; then
    echo "✅ SUCCESS: Main route is now working!"
    
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "161.35.58.110")
    echo ""
    echo "Your HelpBoard is now accessible at:"
    echo "🌐 Main Platform: http://$SERVER_IP:5000"
    echo "🏥 Health Check: http://$SERVER_IP:5000/api/health"
    echo ""
else
    echo "❌ Issue persists. Checking logs:"
    docker compose logs app | tail -10
fi