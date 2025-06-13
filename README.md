# HelpBoard - AI-Powered Customer Support Platform

A comprehensive customer support platform featuring 90% AI-powered responses with intelligent agent takeover capabilities, real-time communication, and embeddable chat widgets.

## Features

- **AI-Powered Support**: 90% automated customer support with OpenAI integration
- **Intelligent Agent Takeover**: Seamless handoff between AI and human agents
- **Real-time Communication**: WebSocket-based instant messaging
- **Embeddable Widget**: Easy integration on external websites
- **Advanced Analytics**: Customer behavior and conversation insights
- **Multi-platform Deployment**: Docker-based deployment for any infrastructure

## Quick Start

### Local Development

```bash
# Clone repository
git clone https://github.com/amowogbaje/HelpBoardFullstackAmowogbaje.git
cd helpboard

# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Start development server
npm run dev
```

### Digital Ocean Production Deployment

```bash
# 1. Set up your Digital Ocean droplet
wget https://raw.githubusercontent.com/your-repo/helpboard/main/digital-ocean-setup.sh
chmod +x digital-ocean-setup.sh
sudo ./digital-ocean-setup.sh

# 2. Clone and configure
git clone https://github.com/amowogbaje/HelpBoardFullstackAmowogbaje.git /opt/helpboard
cd /opt/helpboard
cp .env.example .env
# Configure your .env file

# 3. Deploy with SSL
./deploy.sh init

# 4. Verify deployment
./verify-deployment.sh
```

## Environment Configuration

### Required Environment Variables

```env
# Database
DATABASE_URL=postgresql://user:password@host:port/database
DB_PASSWORD=your_secure_database_password

# OpenAI
OPENAI_API_KEY=your_openai_api_key

# Security
SESSION_SECRET=your_session_secret_32_chars_minimum

# Production Settings
NODE_ENV=production
CORS_ORIGIN=https://your-domain.com
TRUST_PROXY=true
```

## Architecture

### Tech Stack
- **Backend**: Node.js, Express, TypeScript
- **Database**: PostgreSQL with Drizzle ORM
- **Frontend**: React, TanStack Query, Tailwind CSS
- **AI**: OpenAI GPT-4o integration
- **Infrastructure**: Docker, Nginx, Redis

### Key Components
- **AI Service**: Handles automated responses and learning
- **WebSocket Service**: Real-time communication
- **Widget System**: Embeddable chat widgets
- **Agent Dashboard**: Human agent interface
- **Analytics Engine**: Performance tracking

## Widget Integration

### Basic HTML Integration

```html
<script>
  (function() {
    var script = document.createElement('script');
    script.src = 'https://your-domain.com/widget.js';
    script.async = true;
    script.onload = function() {
      HelpBoard.init({
        apiUrl: 'https://your-domain.com',
        theme: 'light',
        position: 'bottom-right',
        companyName: 'Your Company',
        welcomeMessage: 'Hi! How can we help you today?'
      });
    };
    document.head.appendChild(script);
  })();
</script>
```

### React Integration

```jsx
import { useEffect } from 'react';

function ChatWidget() {
  useEffect(() => {
    const script = document.createElement('script');
    script.src = 'https://your-domain.com/widget.js';
    script.async = true;
    script.onload = () => {
      window.HelpBoard.init({
        apiUrl: 'https://your-domain.com',
        theme: 'light',
        position: 'bottom-right'
      });
    };
    document.head.appendChild(script);
  }, []);

  return null;
}
```

## API Documentation

### Authentication
```bash
POST /api/auth/login
Content-Type: application/json

{
  "email": "agent@company.com",
  "password": "password"
}
```

### Conversations
```bash
# Get all conversations
GET /api/conversations
Authorization: Bearer <token>

# Get specific conversation
GET /api/conversations/:id
Authorization: Bearer <token>

# Send message
POST /api/conversations/:id/messages
Authorization: Bearer <token>
Content-Type: application/json

{
  "content": "Message content"
}
```

### Health Check
```bash
GET /api/health
```

## Deployment Options

### Digital Ocean (Recommended)
- Automated setup with `digital-ocean-setup.sh`
- Optimized for Digital Ocean droplets
- SSL certificate automation
- Firewall configuration

### Docker Compose
```bash
# Development
docker-compose up -d

# Production
docker-compose -f docker-compose.prod.yml up -d
```

### Manual Installation
See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions.

## Monitoring

### Health Checks
```bash
# Application health
curl https://your-domain.com/health

# Comprehensive verification
./verify-deployment.sh all
```

### Metrics and Logging
- Prometheus metrics at `/api/metrics`
- Application logs via Docker
- Real-time performance monitoring

## Security

### Production Security Features
- HTTPS with automatic SSL certificate renewal
- Rate limiting and DDoS protection
- Security headers (HSTS, XSS protection)
- Firewall configuration
- fail2ban integration
- Regular security updates

### Authentication
- Session-based authentication
- Secure password hashing with bcrypt
- CSRF protection
- Secure cookie configuration

## AI Training

The platform includes comprehensive AI training capabilities:

### Training Methods
- **Manual Training**: Add Q&A pairs through the dashboard
- **File Upload**: Train from CSV, JSON, or TXT files
- **FAQ Integration**: Import existing FAQ data
- **Conversation Learning**: Learn from successful agent interactions
- **Bulk Training**: Process multiple conversations at once

### AI Configuration
- Response delay settings
- Auto-response thresholds
- Agent takeover triggers
- Temperature and creativity controls

## Troubleshooting

### Common Issues

**Port conflicts:**
```bash
sudo netstat -tlnp | grep ':80\|:443'
sudo kill $(sudo lsof -t -i:80)
```

**SSL certificate issues:**
```bash
./deploy.sh ssl-renew
openssl x509 -in ssl/fullchain.pem -text -noout
```

**Database connection:**
```bash
docker-compose -f docker-compose.prod.yml exec db pg_isready
docker-compose -f docker-compose.prod.yml logs db
```

**Memory issues:**
```bash
docker stats
free -h
# Add swap if needed
sudo fallocate -l 2G /swapfile
```

## Development

### Local Setup
```bash
npm install
npm run dev
```

### Building
```bash
npm run build
```

### Testing
```bash
npm test
npm run test:e2e
```

### Database Migrations
```bash
npm run db:generate
npm run db:migrate
npm run db:studio
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

- **Documentation**: See [DEPLOYMENT.md](DEPLOYMENT.md) and [DIGITAL_OCEAN_DEPLOYMENT.md](DIGITAL_OCEAN_DEPLOYMENT.md)
- **Issues**: Create an issue on GitHub
- **Security**: Report security issues privately

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

Built with ❤️ for better customer support experiences.