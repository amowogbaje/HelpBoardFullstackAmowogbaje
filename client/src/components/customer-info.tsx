import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { 
  User, 
  Mail, 
  Phone, 
  MapPin, 
  Globe, 
  ShoppingBag, 
  Edit, 
  ArrowUp, 
  Ban 
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
  createdAt: string;
}

interface CustomerInfoProps {
  customer: Customer | null;
}

export default function CustomerInfo({ customer }: CustomerInfoProps) {
  if (!customer) {
    return (
      <div className="w-80 bg-white border-l border-slate-200 flex items-center justify-center">
        <div className="text-slate-500 text-center">
          <User className="h-12 w-12 mx-auto mb-4 text-slate-300" />
          <p>Select a conversation to view customer details</p>
        </div>
      </div>
    );
  }

  const formatJoinDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString("en-US", {
      month: "short",
      year: "numeric",
    });
  };

  return (
    <div className="w-80 bg-white border-l border-slate-200 overflow-y-auto">
      {/* Customer Details */}
      <div className="p-4 border-b border-slate-200">
        <h3 className="text-lg font-semibold text-slate-900 mb-4">Customer Details</h3>
        
        <div className="space-y-4">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
              <User className="h-6 w-6 text-primary" />
            </div>
            <div>
              <p className="font-medium text-slate-900">{customer.name || "Anonymous"}</p>
              <p className="text-sm text-slate-500">
                Customer since {formatJoinDate(customer.createdAt)}
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 gap-3">
            {customer.email && (
              <div className="flex items-center space-x-2">
                <Mail className="h-4 w-4 text-slate-400" />
                <span className="text-sm text-slate-600">{customer.email}</span>
              </div>
            )}
            
            {customer.phone && (
              <div className="flex items-center space-x-2">
                <Phone className="h-4 w-4 text-slate-400" />
                <span className="text-sm text-slate-600">{customer.phone}</span>
              </div>
            )}
            
            {(customer.address || customer.country) && (
              <div className="flex items-center space-x-2">
                <MapPin className="h-4 w-4 text-slate-400" />
                <span className="text-sm text-slate-600">
                  {customer.address ? customer.address : customer.country}
                </span>
              </div>
            )}
            
            {customer.timezone && (
              <div className="flex items-center space-x-2">
                <Globe className="h-4 w-4 text-slate-400" />
                <span className="text-sm text-slate-600">
                  {customer.timezone.replace("_", " ")}
                </span>
              </div>
            )}
          </div>

          <div className="flex items-center justify-between pt-2">
            <span className="text-sm font-medium text-slate-900">Customer Status</span>
            <Badge className="bg-green-100 text-green-800">
              Verified
            </Badge>
          </div>
        </div>
      </div>

      {/* Previous Conversations */}
      <div className="p-4 border-b border-slate-200">
        <h4 className="text-sm font-semibold text-slate-900 mb-3">Previous Conversations</h4>
        <div className="space-y-3">
          <div className="p-3 bg-slate-50 rounded-lg">
            <div className="flex items-center justify-between mb-1">
              <span className="text-xs font-medium text-slate-600">Order Issue</span>
              <span className="text-xs text-slate-500">Dec 15, 2023</span>
            </div>
            <p className="text-sm text-slate-700">
              Resolved billing question about subscription charges.
            </p>
          </div>
          <div className="p-3 bg-slate-50 rounded-lg">
            <div className="flex items-center justify-between mb-1">
              <span className="text-xs font-medium text-slate-600">Technical Support</span>
              <span className="text-xs text-slate-500">Nov 28, 2023</span>
            </div>
            <p className="text-sm text-slate-700">
              Helped with account settings and password reset.
            </p>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="p-4">
        <h4 className="text-sm font-semibold text-slate-900 mb-3">Quick Actions</h4>
        <div className="space-y-2">
          <Button 
            variant="outline" 
            size="sm" 
            className="w-full justify-start"
          >
            <ShoppingBag className="h-4 w-4 mr-2" />
            View Order History
          </Button>
          
          <Button 
            variant="outline" 
            size="sm" 
            className="w-full justify-start"
          >
            <Edit className="h-4 w-4 mr-2" />
            Update Information
          </Button>
          
          <Button 
            variant="outline" 
            size="sm" 
            className="w-full justify-start"
          >
            <ArrowUp className="h-4 w-4 mr-2" />
            Escalate to Manager
          </Button>
          
          <Button 
            variant="destructive" 
            size="sm" 
            className="w-full justify-start bg-red-600 hover:bg-red-700"
          >
            <Ban className="h-4 w-4 mr-2" />
            Block Customer
          </Button>
        </div>
      </div>
    </div>
  );
}
