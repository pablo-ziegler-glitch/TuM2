"use client";

import { useState } from "react";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "../../../lib/firebase";
import { useRouter, useSearchParams } from "next/navigation";

export default function AdminLoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirect = searchParams.get("redirect") || "/admin/stores";

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const credential = await signInWithEmailAndPassword(
        auth,
        email,
        password
      );
      // Get ID token and set as cookie for middleware
      const token = await credential.user.getIdToken();
      document.cookie = `__session=${token}; path=/; max-age=3600; SameSite=Strict`;
      router.push(redirect);
    } catch {
      setError("Credenciales inválidas. Solo administradores pueden acceder.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-tum2-surface">
      <div className="w-full max-w-sm rounded-2xl border border-tum2-outline bg-white p-8 shadow-sm">
        <h1 className="mb-1 text-2xl font-bold text-gray-900">TuM2 Admin</h1>
        <p className="mb-6 text-sm text-tum2-on-surface-variant">
          Acceso restringido a administradores
        </p>

        <form onSubmit={handleLogin} className="flex flex-col gap-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">
              Email
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-xl border border-tum2-outline px-4 py-2.5 text-sm outline-none focus:border-tum2-primary focus:ring-1 focus:ring-tum2-primary"
              required
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">
              Contraseña
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-xl border border-tum2-outline px-4 py-2.5 text-sm outline-none focus:border-tum2-primary focus:ring-1 focus:ring-tum2-primary"
              required
            />
          </div>

          {error && (
            <p className="text-sm text-red-600">{error}</p>
          )}

          <button
            type="submit"
            disabled={loading}
            className="mt-2 w-full rounded-xl bg-tum2-primary py-2.5 text-sm font-semibold text-white transition-opacity hover:opacity-90 disabled:opacity-50"
          >
            {loading ? "Verificando..." : "Entrar"}
          </button>
        </form>
      </div>
    </div>
  );
}
