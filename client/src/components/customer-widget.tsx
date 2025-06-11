import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Headphones, X, MessageCircle, Send } from "lucide-react";

interface Message {
  id: number;
  content: string;
  isAgent: boolean;
  timestamp: Date;
}

export default function CustomerWidget() {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 1,
      content: "Hi! Welcome to our support. How can I help you today?",
      isAgent: true,
      timestamp: new Date(),
    },
  ]);
  const [inputValue, setInputValue] = useState("");
  const [sessionId, setSessionId] = useState<string | null>(null);

  useEffect(() => {
    // Initialize customer session when widget is first opened
    if (isOpen && !sessionId) {
      initializeSession();
    }
  }, [isOpen, sessionId]);

  const initializeSession = async () => {
    try {
      const response = await fetch("/api/initiate", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          // Auto-collect browser information
          userAgent: navigator.userAgent,
          platform: navigator.platform,
          language: navigator.language,
          pageUrl: window.location.href,
          pageTitle: document.title,
          referrer: document.referrer,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        }),
      });

      const data = await response.json();
      setSessionId(data.sessionId);
      
      console.log("Customer session initialized:", data);
    } catch (error) {
      console.error("Failed to initialize customer session:", error);
    }
  };

  const sendMessage = async () => {
    if (!inputValue.trim() || !sessionId) return;

    const newMessage: Message = {
      id: Date.now(),
      content: inputValue,
      isAgent: false,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, newMessage]);
    setInputValue("");

    // In a real implementation, this would send via WebSocket
    console.log("Sending customer message:", newMessage.content);
    
    // Simulate agent response
    setTimeout(() => {
      const agentResponse: Message = {
        id: Date.now() + 1,
        content: "Thank you for your message. Let me help you with that right away.",
        isAgent: true,
        timestamp: new Date(),
      };
      setMessages(prev => [...prev, agentResponse]);
    }, 2000);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.preventDefault();
      sendMessage();
    }
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  };

  return (
    <div className="fixed bottom-6 right-6 z-50">
      {/* Chat Widget */}
      {isOpen && (
        <div className="bg-white rounded-lg shadow-xl border border-slate-200 w-80 h-96 flex flex-col mb-4">
          {/* Header */}
          <div className="p-4 bg-primary text-white rounded-t-lg">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <div className="w-6 h-6 bg-white/20 rounded-full flex items-center justify-center">
                  <Headphones className="h-3 w-3" />
                </div>
                <div>
                  <h4 className="font-medium">Customer Support</h4>
                  <p className="text-xs text-blue-100">We're here to help!</p>
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
          <div className="flex-1 p-3 space-y-3 overflow-y-auto bg-slate-50">
            {messages.map((message) => (
              <div
                key={message.id}
                className={`flex items-start space-x-2 ${
                  message.isAgent ? "" : "flex-row-reverse space-x-reverse"
                }`}
              >
                <div className={`w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 ${
                  message.isAgent ? "bg-primary/10" : "bg-slate-200"
                }`}>
                  {message.isAgent ? (
                    <Headphones className="h-3 w-3 text-primary" />
                  ) : (
                    <div className="w-3 h-3 bg-slate-500 rounded-full" />
                  )}
                </div>
                <div className={`max-w-[200px] ${message.isAgent ? "" : "text-right"}`}>
                  <div className={`rounded-lg p-2 shadow-sm text-sm ${
                    message.isAgent
                      ? "bg-white border border-slate-200"
                      : "bg-primary text-white"
                  }`}>
                    <p>{message.content}</p>
                  </div>
                  <div className="text-xs text-slate-400 mt-1">
                    {formatTime(message.timestamp)}
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Input */}
          <div className="p-3 border-t border-slate-200">
            <div className="flex items-center space-x-2">
              <Input
                placeholder="Type your message..."
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyPress={handleKeyPress}
                className="text-sm"
              />
              <Button size="sm" onClick={sendMessage} disabled={!inputValue.trim()}>
                <Send className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Toggle Button */}
      <Button
        onClick={() => setIsOpen(!isOpen)}
        className="w-14 h-14 rounded-full shadow-lg hover:scale-105 transition-transform"
        size="lg"
      >
        <MessageCircle className="h-6 w-6" />
      </Button>
    </div>
  );
}
