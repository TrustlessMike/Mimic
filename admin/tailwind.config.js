/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Primary Meta Azure Blue - Mimic brand color
        primary: {
          50: '#e6f3ff',
          100: '#cce7ff',
          200: '#99cfff',
          300: '#66b7ff',
          400: '#339fff',
          500: '#0082FB',
          600: '#0074e0',
          700: '#0066c4',
          800: '#0052a3',
          900: '#003d7a',
        },
        // Clean light backgrounds
        surface: {
          50: '#ffffff',
          100: '#fafbfc',
          200: '#f4f6f8',
          300: '#e9ecef',
          400: '#dee2e6',
          500: '#ced4da',
        },
        // Text colors
        content: {
          primary: '#1a1d21',
          secondary: '#5c6370',
          tertiary: '#8b929a',
          muted: '#adb5bd',
        },
        // Accent colors
        accent: {
          blue: '#3b82f6',
          cyan: '#06b6d4',
          emerald: '#10b981',
          amber: '#f59e0b',
          rose: '#f43f5e',
          orange: '#f97316',
        },
        // Legacy support - Mimic brand blue
        brand: {
          50: '#e6f3ff',
          100: '#cce7ff',
          200: '#99cfff',
          300: '#66b7ff',
          400: '#339fff',
          500: '#0082FB',
          600: '#0074e0',
          700: '#0066c4',
          800: '#0052a3',
          900: '#003d7a',
        },
        dark: {
          50: '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          850: '#172033',
          900: '#0f172a',
          950: '#020617',
        },
      },
      boxShadow: {
        'soft': '0 2px 8px rgba(0, 0, 0, 0.04)',
        'card': '0 4px 12px rgba(0, 0, 0, 0.05)',
        'elevated': '0 8px 24px rgba(0, 0, 0, 0.08)',
        'glow': '0 0 20px rgba(0, 130, 251, 0.15)',
        'glow-lg': '0 0 40px rgba(0, 130, 251, 0.2)',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['JetBrains Mono', 'Menlo', 'Monaco', 'monospace'],
      },
      borderRadius: {
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
    },
  },
  plugins: [],
}
