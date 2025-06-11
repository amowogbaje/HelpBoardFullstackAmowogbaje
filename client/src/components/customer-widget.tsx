import { useState, useEffect, useRef } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { createWebSocketClient, WebSocketClient } from "@/lib/websocket";
import { Headphones, X, MessageCircle, Send, Bot } from "lucide-react";

interface Message {
  id: number;
  content: string;
  isAgent: boolean;
  isAI?: boolean;
  timestamp: Date;
}

interface CustomerWidgetProps {
  // Props for embedding on external websites
  apiUrl?: string;
  theme?: "light" | "dark";
  accentColor?: string;
  position?: "bottom-right" | "bottom-left" | "top-right" | "top-left";
  companyName?: string;
  welcomeMessage?: string;
  embedded?: boolean;
}

export default function CustomerWidget({
  apiUrl = "",
  theme = "light",
  accentColor = "#2563EB",
  position = "bottom-right",
  companyName = "HelpBoard",
  welcomeMessage = "Hi! Welcome to our support. How can I help you today?",
  embedded = false
}: CustomerWidgetProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState("");
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [conversationId, setConversationId] = useState<number | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [isTyping, setIsTyping] = useState(false);
  const [typingTimeout, setTypingTimeout] = useState<NodeJS.Timeout | null>(null);
  const wsRef = useRef<WebSocketClient | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Position styles
  const getPositionStyles = () => {
    const baseStyles = "fixed z-50";
    switch (position) {
      case "bottom-left":
        return `${baseStyles} bottom-6 left-6`;
      case "top-right":
        return `${baseStyles} top-6 right-6`;
      case "top-left":
        return `${baseStyles} top-6 left-6`;
      default:
        return `${baseStyles} bottom-6 right-6`;
    }
  };

  // Theme styles
  const getThemeStyles = () => {
    return theme === "dark" 
      ? "bg-slate-900 text-white border-slate-700"
      : "bg-white text-slate-900 border-slate-200";
  };

  useEffect(() => {
    if (isOpen && !sessionId) {
      initializeSession();
    }
  }, [isOpen, sessionId]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const initializeSession = async () => {
    try {
      // Get geolocation data for enhanced customer identification
      let locationData = {};
      try {
        const geoResponse = await fetch('https://ipapi.co/json/');
        const geoData = await geoResponse.json();
        locationData = {
          country: geoData.country_name,
          city: geoData.city,
          region: geoData.region,
        };
      } catch (error) {
        console.log('Location detection unavailable');
      }

      const response = await fetch(`${apiUrl}/api/initiate`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          userAgent: navigator.userAgent,
          platform: navigator.platform,
          language: navigator.language,
          pageUrl: window.location.href,
          pageTitle: document.title,
          referrer: document.referrer,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          ...locationData,
        }),
      });

      const data = await response.json();
      setSessionId(data.sessionId);
      setConversationId(data.conversationId);
      
      // Add welcome message
      setMessages([{
        id: 1,
        content: welcomeMessage,
        isAgent: true,
        isAI: true,
        timestamp: new Date(),
      }]);

      // Initialize WebSocket connection
      initializeWebSocket(data.sessionId, data.conversationId);
      
      console.log("Customer session initialized:", data);
    } catch (error) {
      console.error("Failed to initialize customer session:", error);
    }
  };

  const initializeWebSocket = (sessionId: string, conversationId: number) => {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const wsUrl = embedded && apiUrl 
      ? `${protocol}//${new URL(apiUrl).host}/ws`
      : `${protocol}//${window.location.host}/ws`;
    
    const ws = new WebSocketClient(wsUrl);
    wsRef.current = ws;

    ws.onConnectionStateChange((connected) => {
      setIsConnected(connected);
    });

    ws.on("customer_init_success", (message) => {
      console.log("Customer WebSocket connected:", message);
    });

    ws.on("new_message", (message) => {
      const newMessage: Message = {
        id: message.message.id,
        content: message.message.content,
        isAgent: message.message.senderType === "agent",
        isAI: message.message.senderId === -1,
        timestamp: new Date(message.message.createdAt),
      };
      setMessages(prev => [...prev, newMessage]);
    });

    ws.on("typing", (message) => {
      if (message.senderType === "agent" && message.conversationId === conversationId) {
        setIsTyping(message.isTyping);
      }
    });

    ws.on("error", (message) => {
      console.error("WebSocket error:", message.error);
    });

    ws.connect().then(() => {
      ws.send({
        type: "customer_init",
        sessionId: sessionId
      });
    }).catch((error) => {
      console.error("Failed to connect WebSocket:", error);
    });
  };

  const sendMessage = async () => {
    if (!inputValue.trim() || !sessionId || !conversationId) return;

    const newMessage: Message = {
      id: Date.now(),
      content: inputValue,
      isAgent: false,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, newMessage]);
    
    // Send via WebSocket if connected
    if (wsRef.current && wsRef.current.isConnected()) {
      wsRef.current.send({
        type: "message",
        conversationId: conversationId,
        content: inputValue
      });
    }
    
    setInputValue("");
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.preventDefault();
      sendMessage();
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setInputValue(e.target.value);
    
    // Send typing indicator
    if (wsRef.current && wsRef.current.isConnected() && conversationId) {
      wsRef.current.send({
        type: "typing",
        conversationId: conversationId,
        isTyping: true
      });

      // Clear existing timeout
      if (typingTimeout) {
        clearTimeout(typingTimeout);
      }

      // Set new timeout to stop typing
      const timeout = setTimeout(() => {
        if (wsRef.current && wsRef.current.isConnected()) {
          wsRef.current.send({
            type: "typing",
            conversationId: conversationId,
            isTyping: false
          });
        }
      }, 1000);

      setTypingTimeout(timeout);
    }
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  };

  return (
    <div className={getPositionStyles()}>
      {/* Chat Widget */}
      {isOpen && (
        <div className={`rounded-lg shadow-xl border w-80 h-96 flex flex-col mb-4 ${getThemeStyles()}`}>
          {/* Header */}
          <div className="p-4 text-white rounded-t-lg" style={{ backgroundColor: accentColor }}>
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <div className="w-6 h-6 bg-white/20 rounded-full flex items-center justify-center">
                  <Headphones className="h-3 w-3" />
                </div>
                <div>
                  <h4 className="font-medium">{companyName} Support</h4>
                  <div className="flex items-center space-x-1">
                    <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-400' : 'bg-red-400'}`} />
                    <p className="text-xs text-white/80">
                      {isConnected ? "Connected" : "Connecting..."}
                    </p>
                  </div>
                </div>
              </div>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setIsOpen(false)}
                className="text-white/80 hover:text-white hover:bg-white/10 p-1"
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          </div>

          {/* Messages */}
          <div className={`flex-1 p-3 space-y-3 overflow-y-auto ${theme === 'dark' ? 'bg-slate-800' : 'bg-slate-50'}`}>
            {messages.map((message) => (
              <div
                key={message.id}
                className={`flex items-start space-x-2 ${
                  message.isAgent ? "" : "flex-row-reverse space-x-reverse"
                }`}
              >
                <div className={`w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 ${
                  message.isAI 
                    ? "bg-purple-100" 
                    : message.isAgent 
                      ? "bg-blue-100" 
                      : theme === 'dark' ? "bg-slate-600" : "bg-slate-200"
                }`}>
                  {message.isAI ? (
                    <Bot className="h-3 w-3 text-purple-600" />
                  ) : message.isAgent ? (
                    <Headphones className="h-3 w-3" style={{ color: accentColor }} />
                  ) : (
                    <div className={`w-3 h-3 rounded-full ${theme === 'dark' ? 'bg-slate-400' : 'bg-slate-500'}`} />
                  )}
                </div>
                <div className={`max-w-[200px] ${message.isAgent ? "" : "text-right"}`}>
                  <div className={`rounded-lg p-2 shadow-sm text-sm ${
                    message.isAgent
                      ? theme === 'dark' 
                        ? "bg-slate-700 border border-slate-600 text-white"
                        : "bg-white border border-slate-200"
                      : "text-white"
                  }`} style={
                    !message.isAgent ? { backgroundColor: accentColor } : {}
                  }>
                    <p>{message.content}</p>
                  </div>
                  <div className={`text-xs mt-1 ${theme === 'dark' ? 'text-slate-400' : 'text-slate-400'}`}>
                    {formatTime(message.timestamp)}
                  </div>
                </div>
              </div>
            ))}
            
            {/* AI Typing Indicator */}
            {isTyping && (
              <div className="flex items-start space-x-2">
                <div className="w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 bg-purple-100">
                  <Bot className="h-3 w-3 text-purple-600" />
                </div>
                <div className={`rounded-lg p-2 shadow-sm ${
                  theme === 'dark' 
                    ? "bg-slate-700 border border-slate-600" 
                    : "bg-white border border-slate-200"
                }`}>
                  <div className="flex space-x-1">
                    <div className={`w-2 h-2 rounded-full animate-bounce ${theme === 'dark' ? 'bg-slate-400' : 'bg-slate-400'}`} />
                    <div className={`w-2 h-2 rounded-full animate-bounce ${theme === 'dark' ? 'bg-slate-400' : 'bg-slate-400'}`} style={{ animationDelay: "0.1s" }} />
                    <div className={`w-2 h-2 rounded-full animate-bounce ${theme === 'dark' ? 'bg-slate-400' : 'bg-slate-400'}`} style={{ animationDelay: "0.2s" }} />
                  </div>
                </div>
              </div>
            )}
            
            <div ref={messagesEndRef} />
          </div>

          {/* Input */}
          <div className={`p-3 border-t ${theme === 'dark' ? 'border-slate-600' : 'border-slate-200'}`}>
            <div className="flex items-center space-x-2">
              <Input
                placeholder="Type your message..."
                value={inputValue}
                onChange={handleInputChange}
                onKeyPress={handleKeyPress}
                className={`text-sm ${
                  theme === 'dark' 
                    ? 'bg-slate-700 border-slate-600 text-white placeholder-slate-400' 
                    : ''
                }`}
                disabled={!isConnected}
              />
              <Button 
                size="sm" 
                onClick={sendMessage} 
                disabled={!inputValue.trim() || !isConnected}
                style={{ backgroundColor: accentColor }}
                className="hover:opacity-90"
              >
                <Send className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Toggle Button */}
      <Button
        onClick={() => setIsOpen(!isOpen)}
        className="w-14 h-14 rounded-full shadow-lg hover:scale-105 transition-transform border-2 border-white"
        size="lg"
        style={{ backgroundColor: accentColor }}
      >
        {isOpen ? <X className="h-6 w-6" /> : <MessageCircle className="h-6 w-6" />}
      </Button>
    </div>
  );
}
