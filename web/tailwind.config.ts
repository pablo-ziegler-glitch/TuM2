import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        "tum2-primary": "#1A6BFF",
        "tum2-primary-light": "#5E96FF",
        "tum2-primary-dark": "#0047CC",
        "tum2-secondary": "#FF6B35",
        "tum2-surface": "#F8F9FA",
        "tum2-surface-variant": "#EFF1F3",
        "tum2-outline": "#DDE1E7",
        "tum2-on-surface": "#374151",
        "tum2-on-surface-variant": "#6B7280",
        "tum2-success": "#16A34A",
        "tum2-error": "#DC2626",
        "tum2-warning": "#D97706",
        "tum2-duty-blue": "#1A6BFF",
        "tum2-late-night": "#7C3AED",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
      },
    },
  },
  plugins: [],
};

export default config;
