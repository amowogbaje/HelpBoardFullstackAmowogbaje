import { useState, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { RefreshCw, Filter, Search, User } from "lucide-react";

interface Conversation {
  id: number;
  customerId: number;
  assignedAgentId: number | null;
  status: string;
  createdAt: string;
  updatedAt: string;
  customer: {
    id: number;
    name: string;
    email: string;
    country?: string;
  };
  assignedAgent?: {
    id: number;
    name: string;
  };
  lastMessage?: {
    id: number;
    content: string;
    senderType: string;
    createdAt: string;
  };
  unreadCount: number;
  messageCount: number;
}

interface ConversationListProps {
  selectedConversationId?: number;
  onConversationSelect: (conversation: Conversation) => void;
}

export default function ConversationList({ selectedConversationId, onConversationSelect }: ConversationListProps) {
  const [searchTerm, setSearchTerm] = useState("");

  const { data: conversations = [], isLoading, refetch } = useQuery<Conversation[]>({
    queryKey: ["/api/conversations"],
    refetchInterval: 5000, // Refresh every 5 seconds
  });

  // Auto-select first conversation if none selected
  useEffect(() => {
    if (conversations.length > 0 && !selectedConversationId) {
      onConversationSelect(conversations[0]);
    }
  }, [conversations, selectedConversationId, onConversationSelect]);

  // Listen for conversation updates from WebSocket
  useEffect(() => {
    const handleConversationUpdate = () => {
      refetch();
    };

    window.addEventListener("conversation_updated", handleConversationUpdate);
    return () => {
      window.removeEventListener("conversation_updated", handleConversationUpdate);
    };
  }, [refetch]);

  const filteredConversations = conversations.filter(conversation =>
    conversation.customer.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    conversation.customer.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    conversation.lastMessage?.content?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getStatusColor = (status: string) => {
    switch (status) {
      case "open":
        return "bg-amber-100 text-amber-800";
      case "assigned":
        return "bg-blue-100 text-blue-800";
      case "closed":
        return "bg-green-100 text-green-800";
      default:
        return "bg-slate-100 text-slate-800";
    }
  };

  const formatTime = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInMinutes = Math.floor((now.getTime() - date.getTime()) / (1000 * 60));
    
    if (diffInMinutes < 1) return "now";
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    if (diffInMinutes < 1440) return `${Math.floor(diffInMinutes / 60)}h ago`;
    return date.toLocaleDateString();
  };

  const getCountryFlag = (country?: string) => {
    const countryFlags: Record<string, string> = {
      "United States": "🇺🇸",
      "Canada": "🇨🇦",
      "United Kingdom": "🇬🇧",
      "Germany": "🇩🇪",
      "France": "🇫🇷",
      "Spain": "🇪🇸",
      "Italy": "🇮🇹",
      "Japan": "🇯🇵",
      "China": "🇨🇳",
      "India": "🇮🇳",
      "Brazil": "🇧🇷",
      "Australia": "🇦🇺",
    };
    return countryFlags[country || ""] || "🌍";
  };

  if (isLoading) {
    return (
      <div className="w-80 bg-white border-r border-slate-200 flex items-center justify-center">
        <div className="text-slate-500">Loading conversations...</div>
      </div>
    );
  }

  return (
    <div className="w-80 bg-white border-r border-slate-200 flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-slate-200">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-slate-900">Conversations</h2>
          <div className="flex items-center space-x-2">
            <Button variant="ghost" size="sm" onClick={() => refetch()}>
              <RefreshCw className="h-4 w-4" />
            </Button>
            <Button variant="ghost" size="sm">
              <Filter className="h-4 w-4" />
            </Button>
          </div>
        </div>
        <div className="mt-3 relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 h-4 w-4" />
          <Input
            placeholder="Search conversations..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      {/* Conversation List */}
      <div className="flex-1 overflow-y-auto">
        {filteredConversations.length === 0 ? (
          <div className="p-4 text-center text-slate-500">
            {searchTerm ? "No conversations match your search" : "No conversations found"}
          </div>
        ) : (
          filteredConversations.map((conversation) => (
            <div
              key={conversation.id}
              onClick={() => onConversationSelect(conversation)}
              className={`p-4 border-b border-slate-100 hover:bg-slate-50 cursor-pointer transition-colors ${
                selectedConversationId === conversation.id ? "bg-blue-50 border-blue-200" : ""
              }`}
            >
              <div className="flex items-start space-x-3">
                <div className="relative">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                    conversation.lastMessage?.senderType === "agent" && conversation.lastMessage?.content?.includes("AI:")
                      ? "bg-purple-100"
                      : "bg-primary/10"
                  }`}>
                    <User className={`h-5 w-5 ${
                      conversation.lastMessage?.senderType === "agent" && conversation.lastMessage?.content?.includes("AI:")
                        ? "text-purple-600"
                        : "text-primary"
                    }`} />
                  </div>
                  {conversation.unreadCount > 0 && (
                    <div className="absolute -top-1 -right-1 w-3 h-3 bg-red-500 rounded-full" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <p className="text-sm font-medium text-slate-900 truncate">
                      {conversation.customer.name || "Anonymous"}
                    </p>
                    <span className="text-xs text-slate-500">
                      {conversation.lastMessage ? formatTime(conversation.lastMessage.createdAt) : formatTime(conversation.createdAt)}
                    </span>
                  </div>
                  {conversation.lastMessage && (
                    <p className="text-sm text-slate-600 truncate mt-1">
                      {conversation.lastMessage.content}
                    </p>
                  )}
                  <div className="flex items-center justify-between mt-2">
                    <div className="flex items-center space-x-2">
                      <Badge className={`text-xs ${getStatusColor(conversation.status)}`}>
                        {conversation.status}
                      </Badge>
                      <span className="text-xs">
                        {getCountryFlag(conversation.customer.country)}
                      </span>
                    </div>
                    {conversation.unreadCount > 0 && (
                      <span className="text-xs font-medium text-red-600">
                        {conversation.unreadCount} new
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
