# HelpBoard API Documentation

## Overview

HelpBoard provides a comprehensive REST API and WebSocket interface for managing chat support conversations. This documentation covers all endpoints needed to integrate with the HelpBoard system.

**Base URL:** `https://your-helpboard-domain.com/api`

**Authentication:** Bearer token authentication for agent endpoints

**WebSocket URL:** `wss://your-helpboard-domain.com/ws`

## Table of Contents

- [Authentication](#authentication)
- [Customer Chat](#customer-chat)
- [Conversations](#conversations)
- [Messages](#messages)
- [Agent Management](#agent-management)
- [AI Agent](#ai-agent)
- [WebSocket Events](#websocket-events)
- [Error Handling](#error-handling)
- [Integration Examples](#integration-examples)

## Authentication

### POST /api/login

Authenticate an agent and receive a session token.

**Request:**
```json
{
  "email": "agent@company.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "sessionToken": "uuid-session-token",
  "agent": {
    "id": 1,
    "email": "agent@company.com",
    "name": "Agent Name",
    "isAvailable": true
  }
}
```

**Error Responses:**
- `401` - Invalid credentials
- `400` - Invalid request data

### POST /api/logout

Logout the current agent session.

**Headers:**
```
Authorization: Bearer {sessionToken}
```

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

## Customer Chat

### POST /api/initiate

Initialize a new customer chat session with automatic customer identification and demographic data collection.

**Request:**
```json
{
  "name": "Customer Name (optional)",
  "email": "customer@email.com (optional)",
  "phone": "+1234567890 (optional)",
  "address": "123 Main St (optional)",
  "country": "United States (optional)",
  "timezone": "America/New_York (auto-detected)",
  "language": "en (auto-detected)",
  "userAgent": "Mozilla/5.0... (auto-collected)",
  "platform": "MacIntel (auto-collected)",
  "pageUrl": "https://website.com/page (auto-collected)",
  "pageTitle": "Page Title (auto-collected)",
  "referrer": "https://google.com (auto-collected)"
}
```

**Response:**
```json
{
  "sessionId": "uuid-session-id",
  "conversationId": 1,
  "isReturningCustomer": false,
  "customer": {
    "id": 1,
    "sessionId": "uuid-session-id",
    "name": "Friendly Visitor 123",
    "email": "customer@email.com",
    "phone": "+1234567890",
    "address": "123 Main St",
    "country": "United States",
    "ipAddress": "192.168.1.1",
    "userAgent": "Mozilla/5.0...",
    "timezone": "America/New_York",
    "language": "en",
    "isIdentified": true,
    "lastSeen": "2024-01-01T00:00:00.000Z",
    "createdAt": "2024-01-01T00:00:00.000Z"
  }
}
```

**Features:**
- Automatic customer recognition by email or IP address
- Geographic location detection via IP geolocation
- Browser and system information collection
- Auto-generated friendly names for anonymous users
- Returning customer detection with personalized messages

### POST /api/customers/update

Update customer information during an active chat session.

**Headers:**
```
X-Session-ID: {sessionId}
Content-Type: application/json
```

**Request:**
```json
{
  "name": "Updated Customer Name",
  "email": "newemail@example.com",
  "phone": "+1987654321",
  "address": "456 New Street",
  "country": "Canada",
  "customField1": "Additional data",
  "customField2": "More context"
}
```

**Response:**
```json
{
  "message": "Customer information updated successfully"
}
```

## Conversations

### GET /api/conversations

Get all conversations (agent authentication required).

**Headers:**
```
Authorization: Bearer {sessionToken}
```

**Response:**
```json
[
  {
    "id": 1,
    "customerId": 1,
    "assignedAgentId": null,
    "status": "open",
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z",
    "customer": {
      "id": 1,
      "name": "Customer Name",
      "email": "customer@email.com",
      "sessionId": "uuid-session-id"
    },
    "assignedAgent": null,
    "lastMessage": {
      "id": 1,
      "content": "Hello, I need help",
      "senderType": "customer",
      "createdAt": "2024-01-01T00:00:00.000Z"
    },
    "unreadCount": 1,
    "messageCount": 1
  }
]
```

### GET /api/conversations/:id

Get a specific conversation with messages.

**Headers:**
```
Authorization: Bearer {sessionToken}
```

**Response:**
```json
{
  "conversation": {
    "id": 1,
    "customerId": 1,
    "assignedAgentId": null,
    "status": "open",
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  },
  "customer": {
    "id": 1,
    "name": "Customer Name",
    "email": "customer@email.com"
  },
  "messages": [
    {
      "id": 1,
      "conversationId": 1,
      "senderId": 1,
      "senderType": "customer",
      "content": "Hello, I need help",
      "createdAt": "2024-01-01T00:00:00.000Z",
      "sender": {
        "id": 1,
        "name": "Customer Name",
        "email": "customer@email.com"
      }
    }
  ]
}
```

### PATCH /api/conversations/:id/assign

Assign a conversation to an agent.

**Headers:**
```
Authorization: Bearer {sessionToken}
```

**Request:**
```json
{
  "agentId": 1
}
```

**Response:**
```json
{
  "id": 1,
  "customerId": 1,
  "assignedAgentId": 1,
  "status": "assigned",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z"
}
```

### PATCH /api/conversations/:id/close

Close a conversation.

**Headers:**
```
Authorization: Bearer {sessionToken}
```

**Response:**
```json
{
  "id": 1,
  "customerId": 1,
  "assignedAgentId": 1,
  "status": "closed",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z"
}
```

## Messages

### POST /api/messages

Send a new message.

**Request:**
```json
{
  "conversationId": 1,
  "senderId": 1,
  "senderType": "customer",
  "content": "Hello, I need help with my order"
}
```

**Response:**
```json
{
  "id": 1,
  "conversationId": 1,
  "senderId": 1,
  "senderType": "customer",
  "content": "Hello, I need help with my order",
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

## Agent Management

### PATCH /api/agent/availability

Update agent availability status.

**Headers:**
```
Authorization: Bearer {sessionToken}
```

**Request:**
```json
{
  "isAvailable": true
}
```

**Response:**
```json
{
  "id": 1,
  "email": "agent@company.com",
  "name": "Agent Name",
  "isAvailable": true,
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

## AI Agent

HelpBoard includes an intelligent AI agent powered by OpenAI that automatically responds to customer messages when:

- No human agents are available
- Conversations remain unassigned for extended periods
- Configured to provide 24/7 automated support

### AI Agent Features

- **Contextual Responses:** Uses conversation history for relevant replies
- **Professional Tone:** Maintains consistent, helpful communication
- **Escalation Logic:** Knows when to direct customers to human agents
- **Multilingual Support:** Can respond in multiple languages
- **Custom Instructions:** Configurable based on your business needs

### AI Agent Configuration

The AI agent behavior can be customized through environment variables:

```bash
OPENAI_API_KEY=your-openai-api-key
AI_RESPONSE_DELAY=2000  # Delay in milliseconds before AI responds
AI_ENABLE_AUTO_RESPONSE=true  # Enable/disable automatic AI responses
```

### AI Message Identification

AI-generated messages have:
- `senderId: -1` (special AI agent ID)
- `senderType: "agent"`
- `sender.name: "HelpBoard AI Assistant"`

### AI Training Endpoints

#### GET /api/ai/stats

Get AI training statistics (agent authentication required).

**Headers:**
```
Authorization: Bearer {sessionToken}
```

**Response:**
```json
{
  "totalExamples": 150,
  "conversationPatterns": 45
}
```

#### POST /api/ai/retrain

Manually retrain the AI agent (agent authentication required).

**Headers:**
```
Authorization: Bearer {sessionToken}
```

**Request (Optional):**
```json
{
  "conversationId": 1
}
```

**Response:**
```json
{
  "message": "AI retrained with 12 conversations",
  "stats": {
    "totalExamples": 150,
    "conversationPatterns": 45
  }
}
```

### Automatic AI Training

The AI agent automatically learns from closed conversations:

1. **Pattern Recognition:** Extracts customer question and agent response pairs
2. **Quality Learning:** Only learns from successful human agent responses
3. **Context Awareness:** Uses conversation patterns for similar customer inquiries
4. **Continuous Improvement:** Updates responses based on learned patterns
5. **Real-time Application:** Applies learned patterns immediately to new conversations

## WebSocket Events

Connect to `wss://your-domain.com/ws` for real-time updates.

### Connection Events

#### Agent Authentication
```json
{
  "type": "auth",
  "sessionToken": "your-session-token"
}
```

#### Customer Session Initialization
```json
{
  "type": "customer_init",
  "sessionId": "customer-session-id"
}
```

### Message Events

#### Send Message
```json
{
  "type": "message",
  "conversationId": 1,
  "content": "Hello, I need help"
}
```

#### Receive Message
```json
{
  "type": "new_message",
  "message": {
    "id": 1,
    "conversationId": 1,
    "senderId": 1,
    "senderType": "customer",
    "content": "Hello, I need help",
    "createdAt": "2024-01-01T00:00:00.000Z"
  },
  "conversationId": 1
}
```

#### Typing Indicator
```json
{
  "type": "typing",
  "conversationId": 1,
  "isTyping": true
}
```

### Status Events

#### Conversation Assignment
```json
{
  "type": "conversation_assigned",
  "conversationId": 1,
  "agentId": 1
}
```

#### Conversation Closure
```json
{
  "type": "conversation_closed",
  "conversationId": 1
}
```

## Error Handling

### Standard Error Response
```json
{
  "message": "Error description"
}
```

### Common HTTP Status Codes

- `200` - Success
- `400` - Bad Request (invalid data)
- `401` - Unauthorized (missing or invalid token)
- `404` - Not Found (resource doesn't exist)
- `500` - Internal Server Error

### WebSocket Error Handling

- Automatic reconnection after connection loss
- Error events sent through WebSocket connection
- Graceful fallback to REST API when WebSocket unavailable

## Integration Examples

### Embedding the Chat Widget

Add this script to any webpage:

```html
<script>
  window.HelpBoardConfig = {
    apiUrl: 'https://your-helpboard-domain.com',
    primaryColor: '#6366f1',
    title: 'Support Chat',
    subtitle: 'We\'re here to help!',
    position: 'bottom-right'
  };
</script>
<script src="https://your-helpboard-domain.com/widget.js"></script>
```

### Widget Configuration Options

```javascript
window.HelpBoardConfig = {
  apiUrl: 'https://your-domain.com',
  position: 'bottom-right', // bottom-left, top-right, top-left
  theme: 'light', // light, dark
  primaryColor: '#6366f1',
  greeting: 'Hello! How can we help you today?',
  placeholder: 'Type a message...',
  title: 'HelpBoard Support',
  subtitle: "We're here to help!",
  autoOpen: false,
  showOnPages: ['/support', '/checkout'], // Show only on specific pages
  hideOnPages: ['/admin'], // Hide on specific pages
  customCSS: '', // Custom CSS overrides
  zIndex: 1000
};
```

### React Integration Example

```jsx
import { useEffect } from 'react';

function App() {
  useEffect(() => {
    // Configure HelpBoard
    window.HelpBoardConfig = {
      apiUrl: 'https://your-domain.com',
      primaryColor: '#your-brand-color'
    };

    // Load widget script
    const script = document.createElement('script');
    script.src = 'https://your-domain.com/widget.js';
    document.body.appendChild(script);

    // Listen for widget events
    window.addEventListener('helpboard:opened', () => {
      console.log('Chat opened');
    });

    window.addEventListener('helpboard:closed', () => {
      console.log('Chat closed');
    });

    return () => {
      document.body.removeChild(script);
    };
  }, []);

  return <div>Your React App</div>;
}
```

### Backend Integration (Laravel Example)

```php
<?php

class HelpBoardService
{
    private $apiUrl;
    private $apiKey;

    public function __construct()
    {
        $this->apiUrl = config('helpboard.api_url');
        $this->apiKey = config('helpboard.api_key');
    }

    public function getConversations()
    {
        $response = Http::withHeaders([
            'Authorization' => 'Bearer ' . $this->apiKey,
            'Content-Type' => 'application/json'
        ])->get($this->apiUrl . '/api/conversations');

        return $response->json();
    }

    public function sendMessage($conversationId, $content, $agentId)
    {
        $response = Http::withHeaders([
            'Authorization' => 'Bearer ' . $this->apiKey,
            'Content-Type' => 'application/json'
        ])->post($this->apiUrl . '/api/messages', [
            'conversationId' => $conversationId,
            'senderId' => $agentId,
            'senderType' => 'agent',
            'content' => $content
        ]);

        return $response->json();
    }
}
```

### Production Deployment

1. **Environment Variables:**
```bash
NODE_ENV=production
OPENAI_API_KEY=your-openai-api-key
DATABASE_URL=your-database-connection-string
SESSION_SECRET=your-session-secret
```

2. **Build and Start:**
```bash
npm run build
npm start
```

3. **Reverse Proxy (Nginx):**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /ws {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
}
```

---

## Support

For technical support or questions about the HelpBoard API, please contact our development team or consult the documentation repository.
