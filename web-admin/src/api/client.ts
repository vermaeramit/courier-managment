// Shared API client. Holds the JWT, attaches it to every request, and surfaces
// clean error messages. Token is kept in memory + sessionStorage so a refresh
// keeps the session (sessionStorage clears when the tab closes).

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:5080";
const TOKEN_KEY = "courier_admin_token";

let token: string | null = sessionStorage.getItem(TOKEN_KEY);

export function setToken(value: string | null) {
  token = value;
  if (value) sessionStorage.setItem(TOKEN_KEY, value);
  else sessionStorage.removeItem(TOKEN_KEY);
}

export function getToken(): string | null {
  return token;
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (res.status === 204) return undefined as T;

  const text = await res.text();
  const data = text ? JSON.parse(text) : undefined;

  if (!res.ok) {
    const message = (data && (data.message || data.title)) || `Request failed (${res.status})`;
    throw new Error(message);
  }
  return data as T;
}

export const api = {
  get: <T>(path: string) => request<T>("GET", path),
  post: <T>(path: string, body?: unknown) => request<T>("POST", path, body),
  put: <T>(path: string, body?: unknown) => request<T>("PUT", path, body),
};

export { BASE_URL };
