import { useState, useEffect, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { getCurrentAgent } from "@/lib/auth";
import { useWebSocket } from "@/hooks/use-websocket";
import { 
  User, 
  Headphones, 
  Bot, 
  UserPlus, 
  Check, 
  Info, 
  Paperclip, 
  Smile, 
  Send 
} from "lucide-react";

interface Message {
  id: number;
  conversationId: number;
  senderId: number | null;
  senderType: string;
  content: string;
  createdAt: string;
  sender?: {
    id: number;
    name: string;
    email: string;
  };
}

interface Conversation {
  id: number;
  customerId: number;
  assignedAgentId: number | null;
  status: string;
  createdAt: string;
  updatedAt: string;
}

interface Customer {
  id: number;
  name: string;
  email: string;
  phone?: string;
  country?: string;
}

interface ConversationData {
  conversation: Conversation;
  customer: Customer;
  messages: Message[];
}

interface ChatAreaProps {
  conversationId: number | null;
}

export default function ChatArea({ conversationId }: ChatAreaProps) {
  const [messageText, setMessageText] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const agent = getCurrentAgent();
  const queryClient = useQueryClient();
  const { sendMessage, sendTyping, typingUsers } = useWebSocket();

  const { data: conversationData, isLoading } = useQuery<ConversationData>({
    queryKey: ["/api/conversations", conversationId],
    enabled: !!conversationId,
  });

  const assignConversationMutation = useMutation({
    mutationFn: async (agentId: number) => {
      const response = await fetch(`/api/conversations/${conversationId}/assign`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${localStorage.getItem("helpboard_token")}`,
        },
        body: JSON.stringify({ agentId }),
      });
      if (!response.ok) throw new Error("Failed to assign conversation");
      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/conversations"] });
      queryClient.invalidateQueries({ queryKey: ["/api/conversations", conversationId] });
    },
  });

  const closeConversationMutation = useMutation({
    mutationFn: async () => {
      const response = await fetch(`/api/conversations/${conversationId}/close`, {
        method: "PATCH",
        headers: {
          "Authorization": `Bearer ${localStorage.getItem("helpboard_token")}`,
        },
      });
      if (!response.ok) throw new Error("Failed to close conversation");
      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/conversations"] });
      queryClient.invalidateQueries({ queryKey: ["/api/conversations", conversationId] });
    },
  });

  // Scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [conversationData?.messages]);

  // Handle typing
  useEffect(() => {
    let timeout: NodeJS.Timeout;
    
    if (isTyping && conversationId) {
      sendTyping(conversationId, true);
      
      timeout = setTimeout(() => {
        setIsTyping(false);
        sendTyping(conversationId, false);
      }, 1000);
    }

    return () => {
      if (timeout) clearTimeout(timeout);
    };
  }, [isTyping, conversationId, sendTyping]);

  const handleSendMessage = () => {
    if (!messageText.trim() || !conversationId) return;

    sendMessage(conversationId, messageText);
    setMessageText("");
    setIsTyping(false);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setMessageText(e.target.value);
    if (!isTyping) {
      setIsTyping(true);
    }
  };

  const handleAssignToMe = () => {
    if (agent && conversationId) {
      assignConversationMutation.mutate(agent.id);
    }
  };

  const handleCloseConversation = () => {
    if (conversationId) {
      closeConversationMutation.mutate();
    }
  };

  const formatTime = (dateString: string) => {
    return new Date(dateString).toLocaleTimeString([], { 
      hour: "2-digit", 
      minute: "2-digit" 
    });
  };

  const getMessageIcon = (message: Message) => {
    if (message.senderId === -1) {
      return <Bot className="h-4 w-4 text-purple-600" />;
    } else if (message.senderType === "agent") {
      return <Headphones className="h-4 w-4 text-green-600" />;
    } else {
      return <User className="h-4 w-4 text-primary" />;
    }
  };

  const getMessageBg = (message: Message) => {
    if (message.senderId === -1) {
      return "bg-purple-50 border-purple-200";
    } else if (message.senderType === "agent") {
      return "bg-primary text-white";
    } else {
      return "bg-white border-slate-200";
    }
  };

  if (!conversationId) {
    return (
      <div className="flex-1 flex items-center justify-center bg-slate-50">
        <div className="text-center text-slate-500">
          <User className="h-12 w-12 mx-auto mb-4 text-slate-300" />
          <p>Select a conversation to start chatting</p>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="flex-1 flex items-center justify-center bg-slate-50">
        <div className="text-slate-500">Loading conversation...</div>
      </div>
    );
  }

  if (!conversationData) {
    return (
      <div className="flex-1 flex items-center justify-center bg-slate-50">
        <div className="text-slate-500">Conversation not found</div>
      </div>
    );
  }

  const { conversation, customer, messages } = conversationData;

  return (
    <div className="flex-1 flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-slate-200 bg-white">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center">
              <User className="h-5 w-5 text-primary" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-slate-900">
                {customer.name || "Anonymous"}
              </h3>
              <div className="flex items-center space-x-2">
                <span className="text-sm text-slate-500">{customer.email}</span>
                {customer.country && (
                  <>
                    <span className="text-xs text-slate-400">•</span>
                    <span className="text-sm text-slate-500">{customer.country}</span>
                  </>
                )}
              </div>
            </div>
          </div>
          <div className="flex items-center space-x-2">
            {!conversation.assignedAgentId && (
              <Button
                variant="outline"
                size="sm"
                onClick={handleAssignToMe}
                disabled={assignConversationMutation.isPending}
              >
                <UserPlus className="h-4 w-4 mr-2" />
                Assign to Me
              </Button>
            )}
            {conversation.status !== "closed" && (
              <Button
                size="sm"
                onClick={handleCloseConversation}
                disabled={closeConversationMutation.isPending}
                className="bg-green-600 hover:bg-green-700"
              >
                <Check className="h-4 w-4 mr-2" />
                Close
              </Button>
            )}
            <Button variant="ghost" size="sm">
              <Info className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-slate-50">
        {messages.map((message) => {
          const isAgent = message.senderType === "agent";
          const isAI = message.senderId === -1;
          
          return (
            <div
              key={message.id}
              className={`flex items-start space-x-3 ${
                isAgent ? "flex-row-reverse space-x-reverse" : ""
              }`}
            >
              <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                isAI 
                  ? "bg-purple-100" 
                  : isAgent 
                    ? "bg-green-100" 
                    : "bg-primary/10"
              }`}>
                {getMessageIcon(message)}
              </div>
              <div className="flex-1">
                <div className={`flex items-center space-x-2 mb-1 ${
                  isAgent ? "justify-end" : ""
                }`}>
                  {!isAgent && (
                    <>
                      <span className="text-sm font-medium text-slate-900">
                        {message.sender?.name || "Customer"}
                      </span>
                      {isAI && (
                        <Badge variant="secondary" className="bg-purple-100 text-purple-700">
                          AI
                        </Badge>
                      )}
                    </>
                  )}
                  <span className="text-xs text-slate-500">
                    {formatTime(message.createdAt)}
                  </span>
                  {isAgent && !isAI && (
                    <span className="text-sm font-medium text-slate-900">You</span>
                  )}
                </div>
                <div className={`rounded-lg p-3 shadow-sm border ${getMessageBg(message)}`}>
                  <p className={`text-sm ${
                    isAgent && !isAI ? "text-white" : "text-slate-700"
                  }`}>
                    {message.content}
                  </p>
                </div>
              </div>
            </div>
          );
        })}

        {/* Typing indicators */}
        {Array.from(typingUsers.entries()).map(([senderId, { isTyping, senderType }]) => 
          isTyping && senderType === "customer" ? (
            <div key={senderId} className="flex items-start space-x-3">
              <div className="w-8 h-8 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0">
                <User className="h-4 w-4 text-primary" />
              </div>
              <div className="bg-white rounded-lg p-3 shadow-sm border border-slate-200">
                <div className="flex space-x-1">
                  <div className="w-2 h-2 bg-slate-400 rounded-full animate-bounce" />
                  <div className="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style={{ animationDelay: "0.1s" }} />
                  <div className="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style={{ animationDelay: "0.2s" }} />
                </div>
              </div>
            </div>
          ) : null
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Message Input */}
      {conversation.status !== "closed" && (
        <div className="p-4 bg-white border-t border-slate-200">
          <div className="flex items-end space-x-3">
            <div className="flex-1">
              <div className="relative">
                <Textarea
                  placeholder="Type your message..."
                  value={messageText}
                  onChange={handleInputChange}
                  onKeyPress={handleKeyPress}
                  rows={3}
                  className="resize-none pr-20"
                />
                <div className="absolute bottom-3 right-3 flex items-center space-x-2">
                  <Button variant="ghost" size="sm" className="p-1">
                    <Paperclip className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="sm" className="p-1">
                    <Smile className="h-4 w-4" />
                  </Button>
                </div>
              </div>
              <div className="flex items-center justify-between mt-2">
                <div className="flex items-center space-x-3">
                  <label className="flex items-center space-x-2 text-sm text-slate-600">
                    <input type="checkbox" className="rounded border-slate-300" />
                    <span>AI Assist</span>
                  </label>
                  <Button variant="ghost" size="sm" className="text-sm text-slate-500">
                    Templates
                  </Button>
                </div>
                <div className="text-xs text-slate-400">
                  Press <kbd className="px-1 py-0.5 bg-slate-100 rounded text-xs">Shift + Enter</kbd> for new line
                </div>
              </div>
            </div>
            <Button onClick={handleSendMessage} disabled={!messageText.trim()}>
              <Send className="h-4 w-4 mr-2" />
              Send
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
