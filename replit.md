# HelpBoard - AI-Powered Customer Support Platform

## Overview

HelpBoard is a comprehensive customer support platform featuring 90% AI-powered responses with intelligent agent takeover capabilities, real-time communication, and embeddable chat widgets. The application combines modern web technologies to deliver a scalable, production-ready customer support solution.

## System Architecture

### Frontend Architecture
- **Framework**: React 18 with TypeScript
- **Styling**: Tailwind CSS with shadcn/ui components
- **State Management**: TanStack Query for server state, React hooks for local state
- **Routing**: Wouter (lightweight client-side routing)
- **Build Tool**: Vite for development and production builds
- **Real-time Communication**: WebSocket client for live chat functionality

### Backend Architecture
- **Runtime**: Node.js 20 with TypeScript
- **Framework**: Express.js for REST API endpoints
- **WebSocket Server**: ws library for real-time communication
- **Database ORM**: Drizzle ORM with TypeScript-first approach
- **Authentication**: Session-based with Bearer tokens
- **AI Integration**: OpenAI GPT-4o for automated responses

### Data Storage Solutions
- **Primary Database**: PostgreSQL 15 for relational data
- **Session Store**: Redis for session management and caching
- **Database Schema**: Comprehensive schema with agents, customers, conversations, messages, and sessions tables
- **Migrations**: Drizzle Kit for database schema management

## Key Components

### Authentication and Authorization
- Session-based authentication with Bearer tokens
- Role-based access control (admin, agent, supervisor)
- Secure password hashing with bcrypt
- Session persistence in localStorage and Redis

### AI Service Integration
- OpenAI GPT-4o integration for automated responses
- Configurable AI settings (temperature, response delay, takeover threshold)
- Training data management system
- Conversation history tracking for context-aware responses

### Real-time Communication
- WebSocket server for instant messaging
- Typing indicators and presence awareness
- Agent availability status management
- Customer widget for external website embedding

### Customer Management
- Customer identification and tracking
- Session management across multiple visits
- Geographic and browser information collection
- Conversation history and analytics

### Agent Dashboard
- Multi-conversation management interface
- Real-time message handling
- Customer information sidebar
- Conversation assignment and status management

## Data Flow

### Customer Interaction Flow
1. Customer initiates chat via embedded widget or direct interface
2. System creates/retrieves customer session and conversation
3. AI service processes initial messages and provides automated responses
4. If AI confidence is low or customer requests human help, conversation is escalated to available agent
5. Agent receives real-time notification and can take over conversation
6. All interactions are logged and stored for analytics

### Agent Workflow
1. Agent authenticates via login system
2. WebSocket connection established for real-time updates
3. Agent sees list of active conversations with priority indicators
4. Agent can assign conversations to themselves or other agents
5. Real-time messaging with typing indicators and message delivery confirmation

### AI Processing Pipeline
1. Incoming customer message analyzed for intent and context
2. Training data and conversation history used for context
3. OpenAI API generates response with confidence score
4. If confidence above threshold, response sent automatically
5. If below threshold, conversation flagged for agent intervention

## External Dependencies

### Core Dependencies
- **@neondatabase/serverless**: Database connection adapter
- **drizzle-orm**: Type-safe database ORM
- **openai**: Official OpenAI API client
- **express**: Web application framework
- **ws**: WebSocket server implementation
- **bcryptjs**: Password hashing
- **nanoid**: Unique ID generation

### Frontend Dependencies
- **@tanstack/react-query**: Server state management
- **@radix-ui/\***: Accessible UI component primitives
- **tailwindcss**: Utility-first CSS framework
- **wouter**: Lightweight routing
- **react-hook-form**: Form state management

### Development Dependencies
- **vite**: Build tool and dev server
- **typescript**: Type checking
- **tsx**: TypeScript execution
- **esbuild**: Fast bundling for production

## Deployment Strategy

### Development Deployment
- Uses `docker-compose.dev.yml` for local development
- Runs application in development mode with hot reloading
- Includes PostgreSQL and Redis containers
- Port 5000 exposed for application access

### Production Deployment
- Multi-stage Docker builds for optimized images
- Separate production configuration with `docker-compose.prod.yml`
- Nginx reverse proxy for SSL termination and static file serving
- Health checks and resource limits configured
- Automated SSL certificate management with Certbot

### Infrastructure Requirements
- **Minimum**: 2GB RAM, 1 vCPU, 50GB SSD
- **Recommended**: 4GB RAM, 2 vCPU, 80GB SSD
- **Operating System**: Ubuntu 22.04 LTS
- **Docker**: Engine 20.10+ with Compose v2

### Domain and SSL Configuration
- Configured for `helpboard.selfany.com` domain
- Automated SSL certificate provisioning
- HTTP to HTTPS redirection
- Security headers and rate limiting

## Changelog
```
Changelog:
- June 14, 2025. Initial setup
- June 14, 2025. Created comprehensive two-phase deployment system for Digital Ocean
- June 14, 2025. Fixed SSL troubleshooting script syntax errors and added clean ssl-fix.sh
- June 14, 2025. Added automatic git configuration to deployment scripts
```

## User Preferences
```
Preferred communication style: Simple, everyday language.
```