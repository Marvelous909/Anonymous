/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        'elfag-dark': '#173300',
        'elfag-light': '#C8FC3C',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        'industrial': '4px 4px 0 0 #173300',
      }
    },
  },
  plugins: [],
};