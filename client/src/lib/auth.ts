import { apiRequest } from "./queryClient";

export interface Agent {
  id: number;
  email: string;
  name: string;
  isAvailable: boolean;
}

export interface LoginResponse {
  sessionToken: string;
  agent: Agent;
}

let currentAgent: Agent | null = null;
let sessionToken: string | null = null;

export function getCurrentAgent(): Agent | null {
  return currentAgent;
}

export function getSessionToken(): string | null {
  return sessionToken;
}

export function setAuth(token: string, agent: Agent): void {
  sessionToken = token;
  currentAgent = agent;
  localStorage.setItem("helpboard_token", token);
  localStorage.setItem("helpboard_agent", JSON.stringify(agent));
}

export function clearAuth(): void {
  sessionToken = null;
  currentAgent = null;
  localStorage.removeItem("helpboard_token");
  localStorage.removeItem("helpboard_agent");
}

export function loadAuthFromStorage(): boolean {
  const token = localStorage.getItem("helpboard_token");
  const agentData = localStorage.getItem("helpboard_agent");
  
  if (token && agentData) {
    try {
      const agent = JSON.parse(agentData);
      sessionToken = token;
      currentAgent = agent;
      return true;
    } catch (error) {
      console.error("Failed to parse stored agent data:", error);
      clearAuth();
    }
  }
  
  return false;
}

export async function login(email: string, password: string): Promise<LoginResponse> {
  const response = await apiRequest("POST", "/api/login", { email, password });
  const data: LoginResponse = await response.json();
  
  setAuth(data.sessionToken, data.agent);
  return data;
}

export async function logout(): Promise<void> {
  if (sessionToken) {
    try {
      await apiRequest("POST", "/api/logout");
    } catch (error) {
      console.error("Logout error:", error);
    }
  }
  clearAuth();
}

export function isAuthenticated(): boolean {
  return !!sessionToken && !!currentAgent;
}
