import type { Metadata } from "next";
import "./globals.css";
import NavBar from "../components/NavBar";

export const metadata: Metadata = {
  title: "TuM2 — Tu metro cuadrado",
  description:
    "Encontrá los comercios de tu zona. Horarios reales, productos y farmacias de turno.",
  openGraph: {
    title: "TuM2 — Tu metro cuadrado",
    description: "La capa digital del comercio de cercanía.",
    siteName: "TuM2",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body className="min-h-screen bg-white text-gray-900 antialiased">
        <NavBar />
        <main className="mx-auto max-w-5xl px-4 py-6">{children}</main>
        <footer className="mt-16 border-t border-tum2-outline py-8 text-center text-sm text-tum2-on-surface-variant">
          <p>
            TuM2 — Tu metro cuadrado &copy; {new Date().getFullYear()} Floki
            Studio
          </p>
        </footer>
      </body>
    </html>
  );
}
