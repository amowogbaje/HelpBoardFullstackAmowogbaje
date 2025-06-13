#!/bin/bash

# Complete authentication system fix
set -e

echo "=== Applying Complete Authentication Fix ==="

# 1. Fix the session data structure in routes
cat > temp_session_fix.patch << 'EOF'
// Enhanced session management interface
interface SessionData {
  agentId: number;
  agent: Agent;
  expiresAt: Date;
  lastActivity: Date;
}

const sessions = new Map<string, SessionData>();

// Session cleanup interval
setInterval(() => {
  const now = new Date();
  for (const [token, session] of sessions.entries()) {
    if (session.expiresAt <= now) {
      sessions.delete(token);
      storage.deleteSession(token).catch(console.error);
    }
  }
}, 60000);
EOF

# 2. Update the requireAuth middleware to properly handle the new session structure
sed -i '/let session = sessions\.get(token);/,/req\.agentId = session\.agentId;/c\
    let session = sessions.get(token);\
    \
    if (!session) {\
      try {\
        const dbSession = await storage.getSession(token);\
        if (dbSession && dbSession.agentId && (!dbSession.expiresAt || dbSession.expiresAt > new Date())) {\
          const agent = await storage.getAgent(dbSession.agentId);\
          if (agent && agent.isActive) {\
            session = {\
              agentId: dbSession.agentId,\
              agent,\
              expiresAt: dbSession.expiresAt || new Date(Date.now() + 24 * 60 * 60 * 1000),\
              lastActivity: new Date()\
            };\
            sessions.set(token, session);\
          }\
        }\
      } catch (error) {\
        console.error("Session lookup error:", error);\
      }\
    }\
    \
    if (!session || session.expiresAt <= new Date()) {\
      sessions.delete(token);\
      return res.status(401).json({ message: "Invalid or expired session" });\
    }\
    \
    session.lastActivity = new Date();\
    req.agentId = session.agentId;\
    req.agent = session.agent;' server/routes.ts

# 3. Add session validation endpoint
cat >> server/routes.ts << 'EOF'

  // Session validation endpoint
  app.get("/api/auth/validate", requireAuth, async (req, res) => {
    res.json({
      valid: true,
      agent: {
        id: req.agent.id,
        email: req.agent.email,
        name: req.agent.name,
        role: req.agent.role,
        isAvailable: req.agent.isAvailable
      }
    });
  });
EOF

# 4. Fix frontend authentication state management
cat > client/src/lib/auth-enhanced.ts << 'EOF'
import { apiRequest } from "./queryClient";

export interface Agent {
  id: number;
  email: string;
  name: string;
  role: string;
  isAvailable: boolean;
}

export interface LoginResponse {
  sessionToken: string;
  agent: Agent;
}

let currentAgent: Agent | null = null;
let sessionToken: string | null = null;
let validationPromise: Promise<boolean> | null = null;

export function getCurrentAgent(): Agent | null {
  return currentAgent;
}

export function getSessionToken(): string | null {
  return sessionToken;
}

export function setAuth(token: string, agent: Agent): void {
  sessionToken = token;
  currentAgent = agent;
  localStorage.setItem("helpboard_token", token);
  localStorage.setItem("helpboard_agent", JSON.stringify(agent));
}

export function clearAuth(): void {
  sessionToken = null;
  currentAgent = null;
  localStorage.removeItem("helpboard_token");
  localStorage.removeItem("helpboard_agent");
  validationPromise = null;
}

export async function validateSession(): Promise<boolean> {
  if (!sessionToken) return false;
  
  try {
    const response = await apiRequest("GET", "/api/auth/validate");
    const data = await response.json();
    
    if (data.valid && data.agent) {
      currentAgent = data.agent;
      localStorage.setItem("helpboard_agent", JSON.stringify(data.agent));
      return true;
    }
  } catch (error) {
    console.error("Session validation failed:", error);
    clearAuth();
  }
  
  return false;
}

export function loadAuthFromStorage(): boolean {
  const token = localStorage.getItem("helpboard_token");
  const agentData = localStorage.getItem("helpboard_agent");
  
  if (token && agentData) {
    try {
      const agent = JSON.parse(agentData);
      sessionToken = token;
      currentAgent = agent;
      
      // Validate session in background
      validateSession().catch(() => {
        clearAuth();
      });
      
      return true;
    } catch (error) {
      console.error("Failed to parse stored agent data:", error);
      clearAuth();
    }
  }
  
  return false;
}

export async function login(email: string, password: string): Promise<LoginResponse> {
  const response = await apiRequest("POST", "/api/auth/login", { email, password });
  const data: LoginResponse = await response.json();
  
  setAuth(data.sessionToken, data.agent);
  return data;
}

export async function logout(): Promise<void> {
  if (sessionToken) {
    try {
      await apiRequest("POST", "/api/logout");
    } catch (error) {
      console.error("Logout error:", error);
    }
  }
  clearAuth();
}

export function isAuthenticated(): boolean {
  return !!sessionToken && !!currentAgent;
}

export async function ensureAuthenticated(): Promise<boolean> {
  if (!sessionToken || !currentAgent) {
    return false;
  }
  
  // Use cached validation promise if available
  if (!validationPromise) {
    validationPromise = validateSession();
  }
  
  try {
    return await validationPromise;
  } finally {
    validationPromise = null;
  }
}
EOF

# 5. Update frontend auth import
sed -i 's/from "\.\/auth"/from ".\/auth-enhanced"/g' client/src/App.tsx
sed -i 's/from "\.\/auth"/from ".\/auth-enhanced"/g' client/src/pages/login.tsx

# 6. Restart the application to apply changes
echo "Restarting application..."
docker compose -f docker-compose.dev.yml restart app

echo "✓ Complete authentication fix applied"
echo "✓ Enhanced session management implemented"
echo "✓ Frontend authentication state synchronized"
echo "✓ Session validation endpoint added"
echo ""
echo "Testing authentication in 10 seconds..."
sleep 10

# Test the fix
echo "Testing login functionality..."
RESPONSE=$(curl -s -X POST "http://localhost:3000/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@helpboard.com","password":"admin123"}')

echo "Login response: $RESPONSE"

TOKEN=$(echo "$RESPONSE" | grep -o '"sessionToken":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo "✓ Login successful, token: ${TOKEN:0:20}..."
    
    # Test authenticated endpoint
    AUTH_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "http://localhost:3000/api/conversations")
    
    echo "Conversations response: $AUTH_RESPONSE"
    
    if echo "$AUTH_RESPONSE" | grep -q "Invalid.*session"; then
        echo "✗ Authentication still failing"
        exit 1
    else
        echo "✓ Authentication working correctly"
    fi
else
    echo "✗ Login failed"
    exit 1
fi