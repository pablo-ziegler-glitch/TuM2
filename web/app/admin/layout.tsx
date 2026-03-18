import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import Link from "next/link";
import { adminAuth } from "../../lib/firebaseAdmin";

async function verifyAdminSession(): Promise<boolean> {
  try {
    const cookieStore = cookies();
    const sessionCookie = cookieStore.get("__session")?.value;

    if (!sessionCookie) return false;

    const decoded = await adminAuth.verifyIdToken(sessionCookie);

    // Check for admin custom claim or admin role in Firestore
    if (decoded.admin === true) return true;

    // Fallback: check Firestore user document for ADMIN role
    const { adminDb } = await import("../../lib/firebaseAdmin");
    const userSnap = await adminDb.collection("users").doc(decoded.uid).get();
    if (!userSnap.exists) return false;

    return userSnap.data()?.roleType === "ADMIN";
  } catch {
    return false;
  }
}

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const isAdmin = await verifyAdminSession();

  if (!isAdmin) {
    redirect("/admin/login");
  }

  return (
    <div className="min-h-screen bg-tum2-surface">
      {/* Admin nav */}
      <header className="border-b border-tum2-outline bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
          <div className="flex items-center gap-4">
            <span className="font-bold text-tum2-primary">TuM2 Admin</span>
            <nav className="flex items-center gap-3 text-sm">
              <Link
                href="/admin/stores"
                className="rounded-lg px-3 py-1.5 text-gray-600 hover:bg-tum2-surface hover:text-gray-900 transition-colors"
              >
                Comercios
              </Link>
              <Link
                href="/admin/proposals"
                className="rounded-lg px-3 py-1.5 text-gray-600 hover:bg-tum2-surface hover:text-gray-900 transition-colors"
              >
                Propuestas
              </Link>
            </nav>
          </div>
          <Link
            href="/"
            className="text-sm text-tum2-on-surface-variant hover:text-gray-900"
          >
            ← Ver sitio
          </Link>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>
    </div>
  );
}
