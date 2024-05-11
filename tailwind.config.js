/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./_layouts/**/default.html",
    "./_layouts/**/page.html",
    "./_layouts/**/post.html",
    "./_includes/**/*.html",
    "./demos/**/*.html",
    "*.html"
  ],
  theme: {
    extend: {
      fontFamily: {
        lato: ['"Lato"', "sans-serif"],
        "ubuntu-mono": ['"Ubuntu Mono"', "monospace"],
      },
      colors: {
        'ruby': {
          '50': '#fff2f0',
          '100': '#ffe2de',
          '200': '#ffcac3',
          '300': '#ffa599',
          '400': '#ff715e',
          '500': '#ff452c',
          '600': '#f6280c',
          '700': '#d51f06',
          '800': '#ab1d09',
          '900': '#8d1e0f',
          '950': '#4d0b02',
        },
      },
      typography: ({ theme }) => ({
        DEFAULT: {
          css: {
            a: {
              color: theme("colors.ruby.700"),
              "&:hover": {
                color: theme("colors.ruby.500"),
              },
            },
          },
        },
      }),
    },
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("@tailwindcss/forms"),
    require("@tailwindcss/aspect-ratio"),
  ],
};
