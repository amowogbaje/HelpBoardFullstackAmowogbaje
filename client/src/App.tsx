import { Switch, Route, Redirect } from "wouter";
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "./lib/queryClient";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { isAuthenticated, loadAuthFromStorage } from "@/lib/auth";
import { useEffect, useState } from "react";
import Dashboard from "@/pages/dashboard";
import Login from "@/pages/login";
import Customers from "@/pages/customers";
import Analytics from "@/pages/analytics";
import AIAssistant from "@/pages/ai-assistant";
import AITraining from "@/pages/ai-training";
import WidgetGuides from "@/pages/widget-guides";
import NotFound from "@/pages/not-found";

function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isLoading, setIsLoading] = useState(true);
  const [isAuth, setIsAuth] = useState(false);

  useEffect(() => {
    // Load auth from storage and verify session
    const authLoaded = loadAuthFromStorage();
    setIsAuth(authLoaded);
    setIsLoading(false);
  }, []);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return <>{children}</>;
}

function Router() {
  return (
    <Switch>
      <Route path="/login" component={Login} />
      <Route path="/">
        {() => isAuthenticated() ? <Dashboard /> : <Redirect to="/login" />}
      </Route>
      <Route path="/customers">
        {() => isAuthenticated() ? <Customers /> : <Redirect to="/login" />}
      </Route>
      <Route path="/ai">
        {() => isAuthenticated() ? <AIAssistant /> : <Redirect to="/login" />}
      </Route>
      <Route path="/ai-training">
        {() => isAuthenticated() ? <AITraining /> : <Redirect to="/login" />}
      </Route>
      <Route path="/widget-guides">
        {() => isAuthenticated() ? <WidgetGuides /> : <Redirect to="/login" />}
      </Route>
      <Route path="/analytics">
        {() => isAuthenticated() ? <Analytics /> : <Redirect to="/login" />}
      </Route>
      <Route path="/settings">
        {() => isAuthenticated() ? <div>Settings page coming soon...</div> : <Redirect to="/login" />}
      </Route>
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <AuthProvider>
          <Router />
          <Toaster />
        </AuthProvider>
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
