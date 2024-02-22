/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./_layouts/**/default.html",
    "./_layouts/**/page.html",
    "./_layouts/**/post.html",
    "./_includes/**/*.html",
  ],
  theme: {
    extend: {
      fontFamily: {
        lato: ['"Lato"', "sans-serif"],
      },
      colors: {
        ruby: "#d51f06"
      }
    },
  },
  plugins: [],
}

