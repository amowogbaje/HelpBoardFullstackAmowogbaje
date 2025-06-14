# HelpBoard - AI-Powered Customer Support Platform

## Overview

HelpBoard is a comprehensive customer support platform featuring 90% AI-powered responses with intelligent agent takeover capabilities, real-time communication, and embeddable chat widgets. The system combines automated AI assistance with human agent oversight to provide efficient customer support solutions.

## System Architecture

### Frontend Architecture
- **Technology**: React 18 with TypeScript
- **Build Tool**: Vite for fast development and optimized production builds
- **UI Framework**: Tailwind CSS with Radix UI components (shadcn/ui)
- **State Management**: TanStack Query for server state and data fetching
- **Routing**: Wouter for lightweight client-side routing
- **Real-time Communication**: WebSocket client for live messaging

### Backend Architecture
- **Runtime**: Node.js 20 with TypeScript
- **Framework**: Express.js for REST API endpoints
- **Build Tool**: ESBuild for server-side compilation
- **WebSocket**: Native WebSocket server for real-time features
- **AI Integration**: OpenAI GPT-4o for intelligent responses
- **Session Management**: Token-based authentication with in-memory and database session storage

### Database Design
- **Primary Database**: PostgreSQL 15 with Drizzle ORM
- **Session Store**: Redis for fast session and real-time data management
- **Schema**: Comprehensive relational design covering agents, customers, conversations, messages, and AI training data
- **Extensions**: UUID generation and full-text search capabilities

## Key Components

### 1. Agent Management System
- Multi-role support (admin, agent, supervisor)
- Real-time availability tracking
- Performance metrics and conversation assignment
- Password-based authentication with bcrypt hashing

### 2. Customer Interaction Layer
- Anonymous session initiation
- Progressive customer identification
- Multi-platform tracking (IP, user agent, page context)
- Embeddable widget for external websites

### 3. AI-Powered Response Engine
- OpenAI GPT-4o integration for natural language processing
- Configurable response parameters (temperature, length, delay)
- Training data management and conversation pattern learning
- Intelligent escalation to human agents based on confidence thresholds

### 4. Real-time Communication System
- WebSocket-based bidirectional communication
- Typing indicators and presence awareness
- Message queuing and delivery confirmation
- Cross-client synchronization for multi-agent support

### 5. Analytics and Monitoring
- Conversation metrics and performance tracking
- AI effectiveness measurement
- Customer satisfaction scoring
- Agent productivity analytics

## Data Flow

### Customer Interaction Flow
1. Customer initiates conversation via widget or direct interface
2. System creates anonymous session and tracks metadata
3. AI analyzes incoming messages and provides initial responses
4. If AI confidence drops below threshold, conversation escalates to human agent
5. Real-time updates propagate to all connected clients via WebSocket

### Agent Workflow
1. Agents authenticate and set availability status
2. System assigns conversations based on workload and specialization
3. Agents receive real-time notifications for new messages
4. Conversation history and customer context provided for informed responses
5. Actions (assignments, closures, escalations) sync across the platform

### AI Learning Process
1. Training data ingestion from multiple sources (CSV, JSON, FAQ)
2. Conversation pattern analysis and response optimization
3. Continuous learning from successful agent interventions
4. Model fine-tuning based on customer satisfaction feedback

## External Dependencies

### Core Dependencies
- **OpenAI API**: GPT-4o model for AI-powered responses
- **PostgreSQL**: Primary data persistence
- **Redis**: Session management and real-time data caching
- **Node.js 20**: Runtime environment
- **Docker**: Containerization for consistent deployment

### Development Dependencies
- **Vite**: Frontend development server and build tool
- **ESBuild**: Backend TypeScript compilation
- **Drizzle Kit**: Database migrations and schema management
- **Tailwind CSS**: Utility-first styling framework

### Security Dependencies
- **bcryptjs**: Password hashing and validation
- **express-session**: Session management middleware
- **CORS**: Cross-origin resource sharing configuration

## Deployment Strategy

### Development Environment
- Uses `docker-compose.dev.yml` for local development
- Hot reload enabled for both frontend and backend
- PostgreSQL and Redis containers for local data persistence
- Development-optimized build process with source maps

### Production Environment
- Multi-stage Docker builds for optimized image size
- Production-hardened PostgreSQL and Redis configurations
- SSL/TLS termination with Let's Encrypt certificates
- Health checks and automatic restart policies
- Environment-specific configuration management

### Digital Ocean Optimization
- Automated setup scripts for Ubuntu 22.04 LTS droplets
- UFW firewall configuration for security
- Docker Compose orchestration with resource limits
- Monitoring and logging integration
- Backup and recovery procedures

### SSL and Domain Configuration
- Automated SSL certificate provisioning via Certbot
- NGINX reverse proxy for load balancing and SSL termination
- Domain validation and DNS configuration verification
- Automatic certificate renewal processes

## Changelog
- June 14, 2025. Initial setup

## User Preferences

Preferred communication style: Simple, everyday language.