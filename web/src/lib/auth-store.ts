import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { AuthResponse, User } from "./types";

interface AuthState {
  accessToken: string | null;
  refreshToken: string | null;
  user: User | null;
  setAuth: (a: AuthResponse) => void;
  setUser: (u: User) => void;
  clear: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      accessToken: null,
      refreshToken: null,
      user: null,
      setAuth: (a) => set({ accessToken: a.accessToken, refreshToken: a.refreshToken, user: a.user }),
      setUser: (u) => set({ user: u }),
      clear: () => set({ accessToken: null, refreshToken: null, user: null }),
    }),
    { name: "voca-auth" },
  ),
);
