import Link from "next/link";

export default function NotFound() {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center text-center">
      <h1 className="mb-2 text-6xl font-bold text-tum2-primary">404</h1>
      <p className="mb-6 text-lg text-tum2-on-surface-variant">
        Esta página no existe.
      </p>
      <Link
        href="/"
        className="rounded-xl bg-tum2-primary px-6 py-2.5 text-sm font-semibold text-white hover:bg-tum2-primary-dark transition-colors"
      >
        Volver al inicio
      </Link>
    </div>
  );
}
