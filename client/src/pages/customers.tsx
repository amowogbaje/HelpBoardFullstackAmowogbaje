import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { 
  Users, 
  Search, 
  Filter, 
  Download, 
  User, 
  Mail, 
  Phone, 
  MapPin, 
  Clock,
  MessageSquare,
  Globe
} from "lucide-react";

interface Customer {
  id: number;
  name: string;
  email: string;
  phone?: string;
  address?: string;
  country?: string;
  timezone?: string;
  language?: string;
  isIdentified: boolean;
  lastSeen: string;
  createdAt: string;
  conversationCount?: number;
  totalMessages?: number;
}

export default function Customers() {
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedFilter, setSelectedFilter] = useState("all");

  // Mock customer data for now
  const customers: Customer[] = [
    {
      id: 1,
      name: "Emily Rodriguez",
      email: "emily.rodriguez@email.com",
      phone: "+1 (555) 123-4567",
      address: "123 Main St, San Francisco, CA",
      country: "United States",
      timezone: "America/Los_Angeles",
      language: "en",
      isIdentified: true,
      lastSeen: "2024-01-15T10:30:00Z",
      createdAt: "2023-12-01T14:20:00Z",
      conversationCount: 3,
      totalMessages: 15
    },
    {
      id: 2,
      name: "Friendly Visitor 858",
      email: null,
      phone: null,
      address: null,
      country: "Nigeria",
      timezone: "Africa/Lagos",
      language: "en-GB",
      isIdentified: false,
      lastSeen: "2024-01-15T09:45:00Z",
      createdAt: "2024-01-15T09:40:00Z",
      conversationCount: 1,
      totalMessages: 3
    },
    {
      id: 3,
      name: "James Wilson",
      email: "james.wilson@techcorp.com",
      phone: "+44 20 7946 0958",
      address: "456 Tech Street, London",
      country: "United Kingdom",
      timezone: "Europe/London",
      language: "en",
      isIdentified: true,
      lastSeen: "2024-01-14T16:22:00Z",
      createdAt: "2023-11-15T11:00:00Z",
      conversationCount: 7,
      totalMessages: 42
    }
  ];

  const filteredCustomers = customers.filter(customer => {
    const matchesSearch = 
      customer.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      customer.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      customer.country?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesFilter = 
      selectedFilter === "all" ||
      (selectedFilter === "identified" && customer.isIdentified) ||
      (selectedFilter === "anonymous" && !customer.isIdentified) ||
      (selectedFilter === "active" && new Date(customer.lastSeen) > new Date(Date.now() - 24 * 60 * 60 * 1000));
    
    return matchesSearch && matchesFilter;
  });

  const getCountryFlag = (country?: string) => {
    const countryFlags: Record<string, string> = {
      "United States": "🇺🇸",
      "United Kingdom": "🇬🇧",
      "Nigeria": "🇳🇬",
      "Canada": "🇨🇦",
      "Germany": "🇩🇪",
      "France": "🇫🇷",
      "Japan": "🇯🇵",
      "Australia": "🇦🇺",
    };
    return countryFlags[country || ""] || "🌍";
  };

  const formatLastSeen = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInMinutes = Math.floor((now.getTime() - date.getTime()) / (1000 * 60));
    
    if (diffInMinutes < 1) return "Just now";
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    if (diffInMinutes < 1440) return `${Math.floor(diffInMinutes / 60)}h ago`;
    if (diffInMinutes < 10080) return `${Math.floor(diffInMinutes / 1440)}d ago`;
    return date.toLocaleDateString();
  };

  const stats = {
    total: customers.length,
    identified: customers.filter(c => c.isIdentified).length,
    anonymous: customers.filter(c => !c.isIdentified).length,
    active: customers.filter(c => new Date(c.lastSeen) > new Date(Date.now() - 24 * 60 * 60 * 1000)).length
  };

  return (
    <div className="flex h-screen bg-slate-50">
      <div className="flex-1 p-6 overflow-y-auto">
        <div className="max-w-7xl mx-auto space-y-6">
          {/* Header */}
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-slate-900 flex items-center">
                <Users className="h-8 w-8 mr-3 text-primary" />
                Customer Management
              </h1>
              <p className="text-slate-600 mt-1">
                View and manage all your customers and their information
              </p>
            </div>
            <div className="flex space-x-3">
              <Button variant="outline">
                <Download className="h-4 w-4 mr-2" />
                Export
              </Button>
              <Button>
                <User className="h-4 w-4 mr-2" />
                Add Customer
              </Button>
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Total Customers</p>
                    <p className="text-2xl font-bold text-slate-900">{stats.total}</p>
                  </div>
                  <Users className="h-8 w-8 text-blue-500" />
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Identified</p>
                    <p className="text-2xl font-bold text-slate-900">{stats.identified}</p>
                  </div>
                  <User className="h-8 w-8 text-green-500" />
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Anonymous</p>
                    <p className="text-2xl font-bold text-slate-900">{stats.anonymous}</p>
                  </div>
                  <User className="h-8 w-8 text-slate-400" />
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Active (24h)</p>
                    <p className="text-2xl font-bold text-slate-900">{stats.active}</p>
                  </div>
                  <Clock className="h-8 w-8 text-orange-500" />
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Filters and Search */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle>Customer List</CardTitle>
                <div className="flex items-center space-x-3">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 h-4 w-4" />
                    <Input
                      placeholder="Search customers..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      className="pl-10 w-64"
                    />
                  </div>
                  <select
                    value={selectedFilter}
                    onChange={(e) => setSelectedFilter(e.target.value)}
                    className="px-3 py-2 border border-slate-300 rounded-md text-sm"
                  >
                    <option value="all">All Customers</option>
                    <option value="identified">Identified</option>
                    <option value="anonymous">Anonymous</option>
                    <option value="active">Active (24h)</option>
                  </select>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {filteredCustomers.map((customer) => (
                  <div key={customer.id} className="border border-slate-200 rounded-lg p-4 hover:bg-slate-50 transition-colors">
                    <div className="flex items-start justify-between">
                      <div className="flex items-start space-x-4">
                        <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
                          <User className="h-6 w-6 text-primary" />
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center space-x-2 mb-1">
                            <h3 className="text-lg font-medium text-slate-900">
                              {customer.name || "Anonymous"}
                            </h3>
                            {customer.isIdentified ? (
                              <Badge className="bg-green-100 text-green-800">Verified</Badge>
                            ) : (
                              <Badge variant="secondary">Anonymous</Badge>
                            )}
                            <span className="text-lg">{getCountryFlag(customer.country)}</span>
                          </div>
                          
                          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-3">
                            <div className="space-y-2">
                              {customer.email && (
                                <div className="flex items-center space-x-2 text-sm text-slate-600">
                                  <Mail className="h-4 w-4" />
                                  <span>{customer.email}</span>
                                </div>
                              )}
                              {customer.phone && (
                                <div className="flex items-center space-x-2 text-sm text-slate-600">
                                  <Phone className="h-4 w-4" />
                                  <span>{customer.phone}</span>
                                </div>
                              )}
                              {customer.address && (
                                <div className="flex items-center space-x-2 text-sm text-slate-600">
                                  <MapPin className="h-4 w-4" />
                                  <span className="truncate">{customer.address}</span>
                                </div>
                              )}
                            </div>
                            
                            <div className="space-y-2">
                              <div className="flex items-center space-x-2 text-sm text-slate-600">
                                <Globe className="h-4 w-4" />
                                <span>{customer.country || "Unknown"}</span>
                              </div>
                              <div className="flex items-center space-x-2 text-sm text-slate-600">
                                <Clock className="h-4 w-4" />
                                <span>Last seen {formatLastSeen(customer.lastSeen)}</span>
                              </div>
                            </div>
                            
                            <div className="space-y-2">
                              <div className="flex items-center space-x-2 text-sm text-slate-600">
                                <MessageSquare className="h-4 w-4" />
                                <span>{customer.conversationCount} conversations</span>
                              </div>
                              <div className="text-sm text-slate-500">
                                {customer.totalMessages} total messages
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                      
                      <div className="flex space-x-2">
                        <Button variant="outline" size="sm">
                          View Profile
                        </Button>
                        <Button variant="outline" size="sm">
                          <MessageSquare className="h-4 w-4 mr-1" />
                          Chat
                        </Button>
                      </div>
                    </div>
                  </div>
                ))}
                
                {filteredCustomers.length === 0 && (
                  <div className="text-center py-8 text-slate-500">
                    No customers found matching your criteria
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}