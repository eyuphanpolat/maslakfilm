/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#000000',
          light: '#1a1a1a',
          dark: '#000000',
        },
      },
    },
  },
  plugins: [],
  darkMode: 'class',
}

