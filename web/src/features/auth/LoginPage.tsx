import { FormEvent, useState } from "react";
import { api, ApiError } from "../../lib/api";
import { useAuthStore } from "../../lib/auth-store";
import type { AuthResponse } from "../../lib/types";

export function LoginPage() {
  const [mode, setMode] = useState<"login" | "register">("login");
  const [email, setEmail] = useState("admin@voca.local");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const setAuth = useAuthStore((s) => s.setAuth);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const path = mode === "login" ? "/api/auth/login" : "/api/auth/register";
      const body = mode === "login" ? { email, password } : { email, password, displayName };
      const res = await api<AuthResponse>(path, { method: "POST", body: JSON.stringify(body) });
      setAuth(res); // flips the auth gate to the app
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Đăng nhập thất bại");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth-wrap">
      <form className="auth-card" onSubmit={submit}>
        <h1>Voca<span style={{ color: "var(--headword-color)" }}>.</span></h1>
        <p className="sub">{mode === "login" ? "Đăng nhập để học từ vựng TOEIC" : "Tạo tài khoản mới"}</p>
        {mode === "register" && (
          <label style={{ marginBottom: 10 }}><span>Tên hiển thị</span>
            <input value={displayName} onChange={(e) => setDisplayName(e.target.value)} />
          </label>
        )}
        <label style={{ marginBottom: 10 }}><span>Email</span>
          <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" required autoFocus />
        </label>
        <label style={{ marginBottom: 10 }}><span>Mật khẩu</span>
          <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required minLength={6} />
        </label>
        {error && <div className="err">{error}</div>}
        <button className="primary" style={{ width: "100%", marginTop: 16 }} disabled={busy}>
          {busy ? "…" : mode === "login" ? "Đăng nhập" : "Đăng ký"}
        </button>
        <p className="sub" style={{ marginTop: 14, marginBottom: 0 }}>
          {mode === "login" ? "Chưa có tài khoản? " : "Đã có tài khoản? "}
          <a style={{ color: "var(--accent)", cursor: "pointer" }} onClick={() => { setMode(mode === "login" ? "register" : "login"); setError(null); }}>
            {mode === "login" ? "Đăng ký" : "Đăng nhập"}
          </a>
        </p>
      </form>
    </div>
  );
}
