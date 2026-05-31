import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, setToken, getToken, setUnauthorizedHandler } from "../api/client";
import type { LoginResponse, User } from "../api/types";

interface AuthState {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthState | undefined>(undefined);
const USER_KEY = "courier_admin_user";

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(() => {
    const raw = sessionStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as User) : null;
  });

  // Drop the user if the token disappeared (e.g. cleared in another tab).
  useEffect(() => {
    if (user && !getToken()) setUser(null);
  }, [user]);

  function logout() {
    setToken(null);
    sessionStorage.removeItem(USER_KEY);
    setUser(null);
  }

  // Let the API client force a logout on a 401 (expired/revoked token).
  useEffect(() => {
    setUnauthorizedHandler(logout);
    return () => setUnauthorizedHandler(null);
  }, []);

  async function login(email: string, password: string) {
    const res = await api.post<LoginResponse>("/api/auth/login", { email, password });
    setToken(res.token);
    sessionStorage.setItem(USER_KEY, JSON.stringify(res.user));
    setUser(res.user);
  }

  const value = useMemo(() => ({ user, login, logout }), [user]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
