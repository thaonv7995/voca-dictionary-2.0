import "./lib/api-envelope"; // install the API envelope interceptor before any request runs
import { StrictMode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { LoginPage } from "./features/auth/LoginPage";
import { api } from "./lib/api";
import { useAuthStore } from "./lib/auth-store";
import type { User } from "./lib/types";
import "./styles.css";
import "./extra.css";

function Root() {
  const accessToken = useAuthStore((s) => s.accessToken);
  // A persisted accessToken is only a string, not proof of a live session: after its TTL the app
  // used to render anyway and every request 401'd forever. Verify it once at boot — api() silently
  // refreshes an expired token, and clears the session when the refresh token is dead too.
  const [checked, setChecked] = useState(() => !useAuthStore.getState().accessToken);

  useEffect(() => {
    if (checked) return;
    let alive = true;
    api<User>("/api/auth/me")
      .then((user) => {
        if (alive) useAuthStore.getState().setUser(user);
      })
      .catch(() => {
        /* 401 already cleared the session; a network error keeps it and the app retries later */
      })
      .finally(() => {
        if (alive) setChecked(true);
      });
    return () => {
      alive = false;
    };
  }, [checked]);

  if (!checked) return <div className="auth-wrap" />;
  return accessToken ? <App /> : <LoginPage />;
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
);
