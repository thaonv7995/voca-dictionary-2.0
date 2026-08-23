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

// Refresh tokens rotate, so a second tab holding the pre-rotation token would refresh with a
// token the server has already deleted and log itself out. Pull in whatever the other tab wrote.
if (typeof window !== "undefined") {
  window.addEventListener("storage", (e) => {
    if (e.key === "voca-auth") void useAuthStore.persist.rehydrate();
  });
}
