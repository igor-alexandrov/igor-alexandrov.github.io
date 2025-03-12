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
      typography: ({ theme }) => ({
        DEFAULT: {
          css: {
            a: {
              // color: theme("colors.ruby.700"),
              color: 'var(--color-ruby-700)',
              "&:hover": {
                color: 'var(--color-ruby-500)',
              },
            },
          },
        },
      }),
    },
  },
  plugins: [
    // postcss(),
    // require("@tailwindcss/typography"),
    // require("@tailwindcss/forms"),
    // require("@tailwindcss/aspect-ratio"),
  ],
};
