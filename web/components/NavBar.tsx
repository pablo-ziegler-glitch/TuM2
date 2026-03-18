import Link from "next/link";

export default function NavBar() {
  return (
    <header className="sticky top-0 z-40 border-b border-tum2-outline bg-white/90 backdrop-blur-sm">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
        <Link href="/" className="flex items-center gap-2">
          <span className="text-xl font-bold text-tum2-primary">TuM2</span>
          <span className="hidden text-sm text-tum2-on-surface-variant sm:inline">
            Tu metro cuadrado
          </span>
        </Link>
        <nav className="flex items-center gap-4 text-sm font-medium">
          <Link
            href="/"
            className="text-tum2-on-surface hover:text-tum2-primary transition-colors"
          >
            Comercios
          </Link>
          <Link
            href="/farmacias"
            className="text-tum2-on-surface hover:text-tum2-primary transition-colors"
          >
            Farmacias
          </Link>
        </nav>
      </div>
    </header>
  );
}
