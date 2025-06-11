import { Switch, Route, Redirect } from "wouter";
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "./lib/queryClient";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { isAuthenticated, loadAuthFromStorage } from "@/lib/auth";
import Dashboard from "@/pages/dashboard";
import Login from "@/pages/login";
import NotFound from "@/pages/not-found";

// Load auth from storage on app start
loadAuthFromStorage();

function Router() {
  return (
    <Switch>
      <Route path="/login" component={Login} />
      <Route path="/">
        {() => isAuthenticated() ? <Dashboard /> : <Redirect to="/login" />}
      </Route>
      <Route path="/customers">
        {() => isAuthenticated() ? <div>Customers page coming soon...</div> : <Redirect to="/login" />}
      </Route>
      <Route path="/ai">
        {() => isAuthenticated() ? <div>AI Assistant page coming soon...</div> : <Redirect to="/login" />}
      </Route>
      <Route path="/analytics">
        {() => isAuthenticated() ? <div>Analytics page coming soon...</div> : <Redirect to="/login" />}
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
        <Toaster />
        <Router />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
