import { useState } from "react";
import { Button } from "@/components/ui/button";
import { getCurrentAgent, logout } from "@/lib/auth";
import { useLocation } from "wouter";
import { MessageCircle, Users, Bot, BarChart3, Settings, Power, Headphones, Brain, Code } from "lucide-react";

export default function Sidebar() {
  const [location, setLocation] = useLocation();
  const agent = getCurrentAgent();
  const [isAvailable, setIsAvailable] = useState(agent?.isAvailable ?? true);

  const handleLogout = async () => {
    await logout();
    setLocation("/login");
  };

  const toggleAvailability = () => {
    setIsAvailable(!isAvailable);
    // TODO: Update via WebSocket
  };

  const navigationItems = [
    { icon: MessageCircle, label: "Conversations", path: "/", badge: "3" },
    { icon: Users, label: "Customers", path: "/customers" },
    { icon: Bot, label: "AI Assistant", path: "/ai" },
    { icon: Brain, label: "AI Training", path: "/ai-training" },
    { icon: Code, label: "Widget Guides", path: "/widget-guides" },
    { icon: BarChart3, label: "Analytics", path: "/analytics" },
    { icon: Settings, label: "Settings", path: "/settings" },
  ];

  return (
    <div className="w-64 bg-white border-r border-slate-200 flex flex-col">
      {/* Header */}
      <div className="p-6 border-b border-slate-200">
        <div className="flex items-center space-x-3">
          <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
            <Headphones className="text-white text-sm" />
          </div>
          <div>
            <h1 className="text-lg font-semibold text-slate-900">HelpBoard</h1>
            <p className="text-xs text-slate-500">Customer Support</p>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-4 space-y-2">
        {navigationItems.map((item) => {
          const isActive = location === item.path;
          return (
            <button
              key={item.path}
              onClick={() => setLocation(item.path)}
              className={`flex items-center space-x-3 px-3 py-2 rounded-lg w-full transition-colors ${
                isActive
                  ? "bg-primary text-white"
                  : "text-slate-600 hover:bg-slate-100"
              }`}
            >
              <item.icon className="text-sm" />
              <span className="text-sm font-medium">{item.label}</span>
              {item.badge && (
                <span className={`ml-auto text-xs px-2 py-1 rounded-full ${
                  isActive
                    ? "bg-white/20"
                    : "bg-slate-200 text-slate-600"
                }`}>
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Agent Status */}
      <div className="p-4 border-t border-slate-200">
        <div className="flex items-center space-x-3">
          <div className="relative">
            <div className="w-8 h-8 bg-slate-300 rounded-full flex items-center justify-center">
              <Users className="text-slate-600 text-sm" />
            </div>
            <div className={`absolute -bottom-1 -right-1 w-3 h-3 rounded-full border-2 border-white ${
              isAvailable ? "bg-green-500" : "bg-slate-400"
            }`} />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-slate-900 truncate">
              {agent?.name || "Agent"}
            </p>
            <p className={`text-xs ${isAvailable ? "text-green-600" : "text-slate-400"}`}>
              {isAvailable ? "Available" : "Away"}
            </p>
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={toggleAvailability}
            className="text-slate-400 hover:text-slate-600 p-1"
          >
            <Power className="text-sm" />
          </Button>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={handleLogout}
          className="w-full mt-3 text-slate-600"
        >
          Logout
        </Button>
      </div>
    </div>
  );
}
