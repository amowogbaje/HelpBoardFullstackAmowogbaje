import { WebSocketServer, WebSocket } from "ws";
import { Server } from "http";
import { storage } from "./database-storage";
import { aiService } from "./ai-service";

interface WebSocketMessage {
  type: string;
  [key: string]: any;
}

interface ClientConnection {
  ws: WebSocket;
  agentId?: number;
  customerId?: number;
  sessionId?: string;
}

export class WebSocketService {
  private wss: WebSocketServer;
  private clients: Map<WebSocket, ClientConnection> = new Map();
  private typingTimeouts: Map<string, NodeJS.Timeout> = new Map();

  constructor(server: Server) {
    this.wss = new WebSocketServer({ server, path: "/ws" });
    this.setupWebSocket();
  }

  private setupWebSocket(): void {
    this.wss.on("connection", (ws: WebSocket) => {
      console.log("New WebSocket connection");
      
      this.clients.set(ws, { ws });

      ws.on("message", async (data: Buffer) => {
        try {
          const message: WebSocketMessage = JSON.parse(data.toString());
          await this.handleMessage(ws, message);
        } catch (error) {
          console.error("WebSocket message error:", error);
          this.sendError(ws, "Invalid message format");
        }
      });

      ws.on("close", () => {
        console.log("WebSocket connection closed");
        this.clients.delete(ws);
      });

      ws.on("error", (error) => {
        console.error("WebSocket error:", error);
        this.clients.delete(ws);
      });
    });
  }

  private async handleMessage(ws: WebSocket, message: WebSocketMessage): Promise<void> {
    const client = this.clients.get(ws);
    if (!client) return;

    switch (message.type) {
      case "auth":
        await this.handleAuth(ws, message);
        break;
      
      case "customer_init":
        await this.handleCustomerInit(ws, message);
        break;
      
      case "message":
        await this.handleChatMessage(ws, message);
        break;
      
      case "typing":
        await this.handleTyping(ws, message);
        break;
      
      case "agent_availability":
        await this.handleAgentAvailability(ws, message);
        break;
      
      default:
        this.sendError(ws, "Unknown message type");
    }
  }

  private async handleAuth(ws: WebSocket, message: WebSocketMessage): Promise<void> {
    const { sessionToken } = message;
    if (!sessionToken) {
      this.sendError(ws, "Session token required");
      return;
    }

    const session = await storage.getSession(sessionToken);
    if (!session || !session.agentId) {
      this.sendError(ws, "Invalid session token");
      return;
    }

    const agent = await storage.getAgent(session.agentId);
    if (!agent) {
      this.sendError(ws, "Agent not found");
      return;
    }

    const client = this.clients.get(ws);
    if (client) {
      client.agentId = agent.id;
      this.clients.set(ws, client);
    }

    this.send(ws, {
      type: "auth_success",
      agent: {
        id: agent.id,
        name: agent.name,
        email: agent.email,
        isAvailable: agent.isAvailable,
      },
    });

    console.log(`Agent ${agent.name} authenticated via WebSocket`);
  }

  private async handleCustomerInit(ws: WebSocket, message: WebSocketMessage): Promise<void> {
    const { sessionId } = message;
    if (!sessionId) {
      this.sendError(ws, "Session ID required");
      return;
    }

    const customer = await storage.getCustomerBySessionId(sessionId);
    if (!customer) {
      this.sendError(ws, "Customer session not found");
      return;
    }

    const client = this.clients.get(ws);
    if (client) {
      client.customerId = customer.id;
      client.sessionId = sessionId;
      this.clients.set(ws, client);
    }

    this.send(ws, {
      type: "customer_init_success",
      customer: {
        id: customer.id,
        name: customer.name,
        sessionId: customer.sessionId,
      },
    });

    console.log(`Customer ${customer.name} connected via WebSocket`);
  }

  private async handleChatMessage(ws: WebSocket, message: WebSocketMessage): Promise<void> {
    const { conversationId, content } = message;
    const client = this.clients.get(ws);
    if (!client) return;

    let senderId: number | undefined;
    let senderType: string;

    if (client.agentId) {
      senderId = client.agentId;
      senderType = "agent";
    } else if (client.customerId) {
      senderId = client.customerId;
      senderType = "customer";
    } else {
      this.sendError(ws, "Not authenticated");
      return;
    }

    try {
      // Create message
      const newMessage = await storage.createMessage({
        conversationId,
        senderId,
        senderType,
        content,
      });

      // Get message with sender info
      const messageWithSender = await this.getMessageWithSender(newMessage.id);
      
      // Broadcast message to all clients in the conversation
      this.broadcastToConversation(conversationId, {
        type: "new_message",
        message: messageWithSender,
        conversationId,
      });

      // Check if AI should respond
      if (senderType === "customer") {
        await this.checkAIResponse(conversationId, content);
      }

    } catch (error) {
      console.error("Error handling chat message:", error);
      this.sendError(ws, "Failed to send message");
    }
  }

  private async handleTyping(ws: WebSocket, message: WebSocketMessage): Promise<void> {
    const { conversationId, isTyping } = message;
    const client = this.clients.get(ws);
    if (!client) return;

    const typingKey = `${conversationId}-${client.agentId || client.customerId}`;

    if (isTyping) {
      // Clear existing timeout
      const existingTimeout = this.typingTimeouts.get(typingKey);
      if (existingTimeout) {
        clearTimeout(existingTimeout);
      }

      // Broadcast typing indicator
      this.broadcastToConversation(conversationId, {
        type: "typing",
        conversationId,
        isTyping: true,
        senderId: client.agentId || client.customerId,
        senderType: client.agentId ? "agent" : "customer",
      }, ws);

      // Set timeout to stop typing indicator
      const timeout = setTimeout(() => {
        this.broadcastToConversation(conversationId, {
          type: "typing",
          conversationId,
          isTyping: false,
          senderId: client.agentId || client.customerId,
          senderType: client.agentId ? "agent" : "customer",
        }, ws);
        this.typingTimeouts.delete(typingKey);
      }, 3000);

      this.typingTimeouts.set(typingKey, timeout);
    } else {
      // Stop typing immediately
      const existingTimeout = this.typingTimeouts.get(typingKey);
      if (existingTimeout) {
        clearTimeout(existingTimeout);
        this.typingTimeouts.delete(typingKey);
      }

      this.broadcastToConversation(conversationId, {
        type: "typing",
        conversationId,
        isTyping: false,
        senderId: client.agentId || client.customerId,
        senderType: client.agentId ? "agent" : "customer",
      }, ws);
    }
  }

  private async handleAgentAvailability(ws: WebSocket, message: WebSocketMessage): Promise<void> {
    const { isAvailable } = message;
    const client = this.clients.get(ws);
    if (!client || !client.agentId) {
      this.sendError(ws, "Agent not authenticated");
      return;
    }

    try {
      const updatedAgent = await storage.updateAgentAvailability(client.agentId, isAvailable);
      if (updatedAgent) {
        // Broadcast to all connected agents
        this.broadcastToAgents({
          type: "agent_status_changed",
          agent: {
            id: updatedAgent.id,
            name: updatedAgent.name,
            isAvailable: updatedAgent.isAvailable,
          },
        });
      }
    } catch (error) {
      console.error("Error updating agent availability:", error);
      this.sendError(ws, "Failed to update availability");
    }
  }

  private async checkAIResponse(conversationId: number, customerMessage: string): Promise<void> {
    try {
      const conversation = await storage.getConversation(conversationId);
      if (!conversation) return;

      const hasAssignedAgent = conversation.assignedAgentId !== null;
      const timeSinceLastMessage = Date.now() - conversation.updatedAt.getTime();

      const shouldRespond = await aiService.shouldAIRespond(
        conversation.status,
        hasAssignedAgent,
        timeSinceLastMessage
      );

      if (shouldRespond) {
        // Show AI typing indicator immediately
        this.broadcastToConversation(conversationId, {
          type: "typing",
          conversationId,
          isTyping: true,
          senderId: -1,
          senderType: "agent",
          senderName: "HelpBoard AI Assistant"
        });

        // Generate AI response with typing simulation
        setTimeout(async () => {
          const aiResponse = await aiService.generateResponse(
            conversationId,
            customerMessage,
            conversation.customer.name || undefined,
            conversation.customer
          );

          // Stop typing indicator
          this.broadcastToConversation(conversationId, {
            type: "typing",
            conversationId,
            isTyping: false,
            senderId: -1,
            senderType: "agent",
            senderName: "HelpBoard AI Assistant"
          });

          // Send AI message
          const aiMessage = await storage.createMessage({
            conversationId,
            senderId: -1, // Special AI agent ID
            senderType: "agent",
            content: aiResponse,
          });

          const messageWithSender = {
            ...aiMessage,
            sender: {
              id: -1,
              name: "HelpBoard AI Assistant",
              email: "ai@helpboard.com",
            },
          };

          this.broadcastToConversation(conversationId, {
            type: "new_message",
            message: messageWithSender,
            conversationId,
          });
        }, Math.random() * 2000 + 1000); // Random delay 1-3 seconds for natural feel
      }
    } catch (error) {
      console.error("Error in AI response check:", error);
    }
  }

  private async getMessageWithSender(messageId: number) {
    const message = await storage.getMessage(messageId);
    if (!message) return null;

    let sender;
    if (message.senderType === "customer" && message.senderId) {
      sender = await storage.getCustomer(message.senderId);
    } else if (message.senderType === "agent" && message.senderId && message.senderId > 0) {
      sender = await storage.getAgent(message.senderId);
    } else if (message.senderId === -1) {
      sender = {
        id: -1,
        name: "HelpBoard AI Assistant",
        email: "ai@helpboard.com",
      };
    }

    return { ...message, sender };
  }

  private broadcastToConversation(conversationId: number, message: any, excludeWs?: WebSocket): void {
    for (const [ws, client] of this.clients.entries()) {
      if (ws === excludeWs) continue;
      
      // Send to agents (they can see all conversations)
      if (client.agentId) {
        this.send(ws, message);
      }
      // Send to customers only if they're in this conversation
      else if (client.customerId) {
        // Check if customer is in this conversation
        storage.getConversation(conversationId).then(conversation => {
          if (conversation && conversation.customerId === client.customerId) {
            this.send(ws, message);
          }
        });
      }
    }
  }

  private broadcastToAgents(message: any): void {
    for (const [ws, client] of this.clients.entries()) {
      if (client.agentId) {
        this.send(ws, message);
      }
    }
  }

  private send(ws: WebSocket, message: any): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message));
    }
  }

  private sendError(ws: WebSocket, error: string): void {
    this.send(ws, { type: "error", error });
  }

  // Public method to broadcast conversation updates
  broadcastConversationAssigned(conversationId: number, agentId: number): void {
    this.broadcastToAgents({
      type: "conversation_assigned",
      conversationId,
      agentId,
    });
  }

  broadcastConversationClosed(conversationId: number): void {
    this.broadcastToAgents({
      type: "conversation_closed",
      conversationId,
    });
  }
}

let wsService: WebSocketService | null = null;

export function initializeWebSocket(server: Server): WebSocketService {
  wsService = new WebSocketService(server);
  return wsService;
}

export function getWebSocketService(): WebSocketService | null {
  return wsService;
}
