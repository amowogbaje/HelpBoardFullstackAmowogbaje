import { useEffect, useRef, useState } from "react";
import { createWebSocketClient, WebSocketClient, WebSocketMessage } from "@/lib/websocket";
import { getSessionToken } from "@/lib/auth";

export function useWebSocket() {
  const [isConnected, setIsConnected] = useState(false);
  const [messages, setMessages] = useState<any[]>([]);
  const [typingUsers, setTypingUsers] = useState<Map<number, { isTyping: boolean; senderType: string }>>(new Map());
  const wsRef = useRef<WebSocketClient | null>(null);

  useEffect(() => {
    const ws = createWebSocketClient();
    wsRef.current = ws;

    ws.onConnectionStateChange((connected) => {
      setIsConnected(connected);
    });

    // Message handlers
    ws.on("auth_success", (message) => {
      console.log("WebSocket authentication successful:", message.agent);
    });

    ws.on("new_message", (message) => {
      setMessages(prev => [...prev, message.message]);
    });

    ws.on("typing", (message) => {
      setTypingUsers(prev => {
        const newMap = new Map(prev);
        if (message.isTyping) {
          newMap.set(message.senderId, {
            isTyping: true,
            senderType: message.senderType,
          });
        } else {
          newMap.delete(message.senderId);
        }
        return newMap;
      });
    });

    ws.on("conversation_assigned", (message) => {
      console.log("Conversation assigned:", message);
      // Trigger conversation list refresh
      window.dispatchEvent(new CustomEvent("conversation_updated"));
    });

    ws.on("conversation_closed", (message) => {
      console.log("Conversation closed:", message);
      // Trigger conversation list refresh
      window.dispatchEvent(new CustomEvent("conversation_updated"));
    });

    ws.on("agent_takeover", (message) => {
      console.log("Agent takeover:", message);
      // Show notification that agent has joined
      window.dispatchEvent(new CustomEvent("agent_takeover", { 
        detail: { conversationId: message.conversationId, message: message.message }
      }));
    });

    ws.on("agent_status_changed", (message) => {
      console.log("Agent status changed:", message.agent);
    });

    ws.on("error", (message) => {
      console.error("WebSocket error:", message.error);
    });

    // Connect and authenticate
    ws.connect().then(() => {
      const token = getSessionToken();
      if (token) {
        ws.send({ type: "auth", sessionToken: token });
      }
    }).catch((error) => {
      console.error("Failed to connect WebSocket:", error);
    });

    return () => {
      ws.disconnect();
    };
  }, []);

  const sendMessage = (conversationId: number, content: string) => {
    if (wsRef.current && wsRef.current.isConnected()) {
      wsRef.current.send({
        type: "message",
        conversationId,
        content,
      });
    }
  };

  const sendTyping = (conversationId: number, isTyping: boolean) => {
    if (wsRef.current && wsRef.current.isConnected()) {
      wsRef.current.send({
        type: "typing",
        conversationId,
        isTyping,
      });
    }
  };

  const updateAgentAvailability = (isAvailable: boolean) => {
    if (wsRef.current && wsRef.current.isConnected()) {
      wsRef.current.send({
        type: "agent_availability",
        isAvailable,
      });
    }
  };

  return {
    isConnected,
    messages,
    typingUsers,
    sendMessage,
    sendTyping,
    updateAgentAvailability,
  };
}
