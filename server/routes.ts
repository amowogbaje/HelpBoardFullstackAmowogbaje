import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./database-storage";
import { aiService } from "./ai-service";
import { initializeWebSocket, getWebSocketService } from "./websocket";
import { 
  loginSchema, 
  customerInitiateSchema, 
  insertMessageSchema,
  type LoginRequest,
  type CustomerInitiateRequest 
} from "@shared/schema";
import { nanoid } from "nanoid";

// Simple session store
const sessions = new Map<string, { agentId: number; expiresAt: Date }>();

// Middleware to check agent authentication
async function requireAuth(req: any, res: any, next: any) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Authorization required" });
  }

  const token = authHeader.slice(7);
  let session = sessions.get(token);
  
  // If not in memory, check database
  if (!session) {
    try {
      const dbSession = await storage.getSession(token);
      if (dbSession && (!dbSession.expiresAt || dbSession.expiresAt > new Date())) {
        session = { 
          agentId: dbSession.agentId || 0, 
          expiresAt: dbSession.expiresAt || new Date(Date.now() + 24 * 60 * 60 * 1000) 
        };
        sessions.set(token, session);
      }
    } catch (error) {
      console.error("Error checking session:", error);
    }
  }
  
  if (!session || session.expiresAt < new Date()) {
    sessions.delete(token);
    return res.status(401).json({ message: "Invalid or expired session" });
  }

  req.agentId = session.agentId;
  next();
}

// Middleware to get customer from session header
async function getCustomerFromSession(req: any, res: any, next: any) {
  const sessionId = req.headers["x-session-id"];
  if (sessionId) {
    const customer = await storage.getCustomerBySessionId(sessionId);
    req.customer = customer;
  }
  next();
}

function getClientIP(req: any): string {
  return req.headers["x-forwarded-for"]?.split(",")[0] || req.connection.remoteAddress || "127.0.0.1";
}

export async function registerRoutes(app: Express): Promise<Server> {
  const httpServer = createServer(app);
  
  // Initialize WebSocket
  initializeWebSocket(httpServer);

  // Authentication endpoints
  app.post("/api/login", async (req, res) => {
    try {
      const { email, password } = loginSchema.parse(req.body);
      
      const agent = await storage.validateAgent(email, password);
      if (!agent) {
        return res.status(401).json({ message: "Invalid credentials" });
      }

      const sessionToken = nanoid();
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
      
      sessions.set(sessionToken, { agentId: agent.id, expiresAt });
      
      // Store session in storage as well
      await storage.createSession({
        id: sessionToken,
        agentId: agent.id,
        data: { email: agent.email },
        expiresAt,
      });

      res.json({
        sessionToken,
        agent: {
          id: agent.id,
          email: agent.email,
          name: agent.name,
          isAvailable: agent.isAvailable,
        },
      });
    } catch (error) {
      console.error("Login error:", error);
      res.status(400).json({ message: "Invalid request data" });
    }
  });

  app.post("/api/logout", requireAuth, async (req, res) => {
    const authHeader = req.headers.authorization;
    if (authHeader) {
      const token = authHeader.slice(7);
      sessions.delete(token);
      await storage.deleteSession(token);
    }
    res.json({ message: "Logged out successfully" });
  });

  // Customer chat initiation
  app.post("/api/initiate", async (req, res) => {
    try {
      const customerData = customerInitiateSchema.parse(req.body);
      const ipAddress = getClientIP(req);
      
      // Generate session ID
      const sessionId = nanoid();
      
      // Check for returning customer by email or IP
      let existingCustomer = null;
      if (customerData.email) {
        existingCustomer = await storage.getCustomerByEmail(customerData.email);
      }
      if (!existingCustomer && ipAddress) {
        existingCustomer = await storage.getCustomerByIp(ipAddress);
      }

      const isReturningCustomer = !!existingCustomer;
      
      // Create or update customer
      let customer;
      if (existingCustomer) {
        customer = await storage.updateCustomer(existingCustomer.id, {
          ...customerData,
          sessionId,
          ipAddress,
          lastSeen: new Date(),
        });
      } else {
        // Generate friendly name if not provided
        const name = customerData.name || `Friendly Visitor ${Math.floor(Math.random() * 1000)}`;
        
        customer = await storage.createCustomer({
          ...customerData,
          sessionId,
          name,
          ipAddress,
          isIdentified: !!(customerData.email || customerData.name),
        });
      }

      if (!customer) {
        throw new Error("Failed to create customer");
      }

      // Create conversation
      const conversation = await storage.createConversation({
        customerId: customer.id,
        status: "open",
      });

      res.json({
        sessionId,
        conversationId: conversation.id,
        isReturningCustomer,
        customer,
      });
    } catch (error) {
      console.error("Initiate error:", error);
      res.status(400).json({ message: "Invalid request data" });
    }
  });

  // Update customer information
  app.post("/api/customers/update", getCustomerFromSession, async (req, res) => {
    try {
      if (!req.customer) {
        return res.status(400).json({ message: "Customer session not found" });
      }

      const updates = customerInitiateSchema.parse(req.body);
      const updatedCustomer = await storage.updateCustomer(req.customer.id, updates);
      
      if (!updatedCustomer) {
        return res.status(404).json({ message: "Customer not found" });
      }

      res.json({ message: "Customer information updated successfully" });
    } catch (error) {
      console.error("Update customer error:", error);
      res.status(400).json({ message: "Invalid request data" });
    }
  });

  // Conversations
  app.get("/api/conversations", requireAuth, async (req, res) => {
    try {
      const conversations = await storage.getConversations();
      res.json(conversations);
    } catch (error) {
      console.error("Get conversations error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.get("/api/conversations/:id", requireAuth, async (req, res) => {
    try {
      const conversationId = parseInt(req.params.id);
      console.log("Fetching conversation:", conversationId);
      
      const conversationData = await storage.getConversation(conversationId);
      console.log("Conversation data:", conversationData ? "found" : "not found");
      
      if (!conversationData) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      const { messages, customer, ...conversation } = conversationData;
      
      console.log("Returning conversation with", messages?.length || 0, "messages");
      
      res.json({
        conversation,
        customer,
        messages,
      });
    } catch (error) {
      console.error("Get conversation error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.patch("/api/conversations/:id/assign", requireAuth, async (req, res) => {
    try {
      const conversationId = parseInt(req.params.id);
      const { agentId } = req.body;
      
      const conversation = await storage.assignConversation(conversationId, agentId || req.agentId);
      
      if (!conversation) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      // Broadcast via WebSocket
      const wsService = getWebSocketService();
      if (wsService) {
        wsService.broadcastConversationAssigned(conversationId, agentId || req.agentId);
      }

      res.json(conversation);
    } catch (error) {
      console.error("Assign conversation error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.patch("/api/conversations/:id/close", requireAuth, async (req, res) => {
    try {
      const conversationId = parseInt(req.params.id);
      const conversation = await storage.closeConversation(conversationId);
      
      if (!conversation) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      // Clear AI history for closed conversation
      aiService.clearHistory(conversationId);

      // Broadcast via WebSocket
      const wsService = getWebSocketService();
      if (wsService) {
        wsService.broadcastConversationClosed(conversationId);
      }

      res.json(conversation);
    } catch (error) {
      console.error("Close conversation error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // Messages
  app.post("/api/messages", async (req, res) => {
    try {
      const messageData = insertMessageSchema.parse(req.body);
      const message = await storage.createMessage(messageData);
      res.json(message);
    } catch (error) {
      console.error("Create message error:", error);
      res.status(400).json({ message: "Invalid request data" });
    }
  });

  // Agent management
  app.patch("/api/agent/availability", requireAuth, async (req, res) => {
    try {
      const { isAvailable } = req.body;
      const agent = await storage.updateAgentAvailability(req.agentId, isAvailable);
      
      if (!agent) {
        return res.status(404).json({ message: "Agent not found" });
      }

      res.json(agent);
    } catch (error) {
      console.error("Update availability error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // Agent profile management
  app.get("/api/agents/profile", requireAuth, async (req, res) => {
    try {
      const agent = await storage.getAgent(req.agentId);
      if (!agent) {
        return res.status(404).json({ message: "Agent not found" });
      }
      
      // Remove password from response
      const { password, ...agentData } = agent;
      res.json(agentData);
    } catch (error) {
      console.error("Get agent profile error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.patch("/api/agents/profile", requireAuth, async (req, res) => {
    try {
      const updateData = req.body;
      const agent = await storage.updateAgent(req.agentId, updateData);
      
      if (!agent) {
        return res.status(404).json({ message: "Agent not found" });
      }

      // Remove password from response
      const { password, ...agentData } = agent;
      res.json(agentData);
    } catch (error) {
      console.error("Update agent profile error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.post("/api/agents/change-password", requireAuth, async (req, res) => {
    try {
      const { currentPassword, newPassword } = req.body;
      
      if (!currentPassword || !newPassword) {
        return res.status(400).json({ message: "Current password and new password are required" });
      }

      const success = await storage.changeAgentPassword(req.agentId, currentPassword, newPassword);
      
      if (!success) {
        return res.status(400).json({ message: "Current password is incorrect" });
      }

      res.json({ message: "Password changed successfully" });
    } catch (error) {
      console.error("Change password error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // Admin-only routes
  async function requireAdmin(req: any, res: any, next: any) {
    try {
      const agent = await storage.getAgent(req.agentId);
      if (!agent || agent.role !== "admin") {
        return res.status(403).json({ message: "Admin access required" });
      }
      next();
    } catch (error) {
      console.error("Admin check error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  }

  // Admin: Get all agents with statistics
  app.get("/api/admin/agents", requireAuth, requireAdmin, async (req, res) => {
    try {
      const agents = await storage.getAllAgentsWithStats();
      res.json(agents);
    } catch (error) {
      console.error("Get all agents error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // Admin: Create new agent
  app.post("/api/admin/agents", requireAuth, requireAdmin, async (req, res) => {
    try {
      const agentData = req.body;
      
      if (!agentData.email || !agentData.name || !agentData.password) {
        return res.status(400).json({ message: "Email, name, and password are required" });
      }

      const agent = await storage.createAgent(agentData);
      
      // Remove password from response
      const { password, ...agentResponse } = agent;
      res.status(201).json(agentResponse);
    } catch (error) {
      console.error("Create agent error:", error);
      if (error.message?.includes("duplicate") || error.message?.includes("unique")) {
        res.status(400).json({ message: "An agent with this email already exists" });
      } else {
        res.status(500).json({ message: "Internal server error" });
      }
    }
  });

  // Admin: Update agent
  app.patch("/api/admin/agents/:id", requireAuth, requireAdmin, async (req, res) => {
    try {
      const agentId = parseInt(req.params.id);
      const updateData = req.body;
      
      if (isNaN(agentId)) {
        return res.status(400).json({ message: "Invalid agent ID" });
      }

      const agent = await storage.adminUpdateAgent(agentId, updateData);
      
      if (!agent) {
        return res.status(404).json({ message: "Agent not found" });
      }

      // Remove password from response
      const { password, ...agentResponse } = agent;
      res.json(agentResponse);
    } catch (error) {
      console.error("Update agent error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // Admin: Delete agent
  app.delete("/api/admin/agents/:id", requireAuth, requireAdmin, async (req, res) => {
    try {
      const agentId = parseInt(req.params.id);
      
      if (isNaN(agentId)) {
        return res.status(400).json({ message: "Invalid agent ID" });
      }

      // Prevent deleting yourself
      if (agentId === req.agentId) {
        return res.status(400).json({ message: "Cannot delete your own account" });
      }

      const success = await storage.deleteAgent(agentId);
      
      if (!success) {
        return res.status(404).json({ message: "Agent not found" });
      }

      res.json({ message: "Agent deleted successfully" });
    } catch (error) {
      console.error("Delete agent error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // AI endpoints
  app.get("/api/ai/stats", requireAuth, async (req, res) => {
    try {
      const stats = aiService.getStats();
      res.json(stats);
    } catch (error) {
      console.error("AI stats error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.get("/api/ai/training-data", requireAuth, async (req, res) => {
    try {
      const trainingData = aiService.getTrainingData();
      res.json(trainingData);
    } catch (error) {
      console.error("Get training data error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.post("/api/ai/training-data", requireAuth, async (req, res) => {
    try {
      const { question, answer, category, context } = req.body;
      
      if (!question || !answer || !category) {
        return res.status(400).json({ message: "Question, answer, and category are required" });
      }
      
      aiService.addTrainingData(question, answer, category, context);
      res.json({ message: "Training data added successfully" });
    } catch (error) {
      console.error("Add training data error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.put("/api/ai/training-data/:index", requireAuth, async (req, res) => {
    try {
      const index = parseInt(req.params.index);
      const { question, answer, category, context } = req.body;
      
      if (!question || !answer || !category) {
        return res.status(400).json({ message: "Question, answer, and category are required" });
      }
      
      aiService.updateTrainingData(index, { question, answer, category, context });
      res.json({ message: "Training data updated successfully" });
    } catch (error) {
      console.error("Update training data error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.delete("/api/ai/training-data/:index", requireAuth, async (req, res) => {
    try {
      const index = parseInt(req.params.index);
      aiService.removeTrainingData(index);
      res.json({ message: "Training data deleted successfully" });
    } catch (error) {
      console.error("Delete training data error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.get("/api/ai/settings", requireAuth, async (req, res) => {
    try {
      const settings = aiService.getSettings();
      res.json(settings);
    } catch (error) {
      console.error("Get AI settings error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.put("/api/ai/settings", requireAuth, async (req, res) => {
    try {
      aiService.updateSettings(req.body);
      res.json({ message: "AI settings updated successfully" });
    } catch (error) {
      console.error("Update AI settings error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.post("/api/ai/retrain", requireAuth, async (req, res) => {
    try {
      // Get all conversations and retrain AI
      const conversations = await storage.getConversations();
      let trainedCount = 0;
      
      for (const conv of conversations) {
        const messages = await storage.getMessagesByConversation(conv.id);
        const customerMessages = messages.filter(m => m.senderType === 'customer').map(m => m.content);
        const agentMessages = messages.filter(m => m.senderType === 'agent' && m.senderId !== -1).map(m => m.content);
        
        if (customerMessages.length > 0 && agentMessages.length > 0) {
          await aiService.trainFromConversation(conv.id, customerMessages, agentMessages);
          trainedCount++;
        }
      }
      
      res.json({ message: `AI retrained with ${trainedCount} conversations`, trainedCount });
    } catch (error) {
      console.error("Retrain error:", error);
      res.status(500).json({ error: "Failed to retrain AI" });
    }
  });

  // File-based training
  app.post("/api/ai/train/file", requireAuth, async (req, res) => {
    try {
      const { content, format } = req.body;
      if (!content || !format) {
        return res.status(400).json({ error: "Content and format are required" });
      }
      
      const result = await aiService.trainFromFile(content, format);
      res.json(result);
    } catch (error) {
      console.error("File training error:", error);
      res.status(500).json({ error: "Failed to train from file" });
    }
  });

  // FAQ training
  app.post("/api/ai/train/faq", requireAuth, async (req, res) => {
    try {
      const { faqData } = req.body;
      if (!Array.isArray(faqData)) {
        return res.status(400).json({ error: "FAQ data must be an array" });
      }
      
      const count = await aiService.trainFromFAQ(faqData);
      res.json({ message: `Added ${count} FAQ entries`, count });
    } catch (error) {
      console.error("FAQ training error:", error);
      res.status(500).json({ error: "Failed to train from FAQ" });
    }
  });

  // Knowledge base training
  app.post("/api/ai/train/knowledge-base", requireAuth, async (req, res) => {
    try {
      const { articles } = req.body;
      if (!Array.isArray(articles)) {
        return res.status(400).json({ error: "Articles must be an array" });
      }
      
      const count = await aiService.trainFromKnowledgeBase(articles);
      res.json({ message: `Added ${count} knowledge base entries`, count });
    } catch (error) {
      console.error("Knowledge base training error:", error);
      res.status(500).json({ error: "Failed to train from knowledge base" });
    }
  });

  // Bulk conversation training
  app.post("/api/ai/train/bulk", requireAuth, async (req, res) => {
    try {
      const { conversations } = req.body;
      if (!Array.isArray(conversations)) {
        return res.status(400).json({ error: "Conversations must be an array" });
      }
      
      const count = await aiService.performBulkTraining(conversations);
      res.json({ message: `Bulk trained ${count} conversation pairs`, count });
    } catch (error) {
      console.error("Bulk training error:", error);
      res.status(500).json({ error: "Failed to perform bulk training" });
    }
  });

  // Optimize training data
  app.post("/api/ai/optimize", requireAuth, async (req, res) => {
    try {
      const result = await aiService.optimizeTrainingData();
      res.json(result);
    } catch (error) {
      console.error("Optimization error:", error);
      res.status(500).json({ error: "Failed to optimize training data" });
    }
  });

  // Export training data
  app.get("/api/ai/export/:format", requireAuth, async (req, res) => {
    try {
      const { format } = req.params;
      if (format !== 'csv' && format !== 'json') {
        return res.status(400).json({ error: "Format must be csv or json" });
      }
      
      const data = aiService.exportTrainingData(format);
      const filename = `training-data-${Date.now()}.${format}`;
      
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.setHeader('Content-Type', format === 'csv' ? 'text/csv' : 'application/json');
      res.send(data);
    } catch (error) {
      console.error("Export error:", error);
      res.status(500).json({ error: "Failed to export training data" });
    }
  });

  // Serve widget.js for external embedding
  app.get("/widget.js", (req, res) => {
    res.setHeader("Content-Type", "application/javascript");
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.setHeader("Cache-Control", "public, max-age=3600"); // Cache for 1 hour
    res.sendFile("widget.js", { root: "./client/public" });
  });

  return httpServer;
}
