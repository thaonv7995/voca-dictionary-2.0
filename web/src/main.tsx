import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { LoginPage } from "./features/auth/LoginPage";
import { useAuthStore } from "./lib/auth-store";
import "./styles.css";
import "./extra.css";

function Root() {
  const accessToken = useAuthStore((s) => s.accessToken);
  return accessToken ? <App /> : <LoginPage />;
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
);
