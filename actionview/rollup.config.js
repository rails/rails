import { terser } from "rollup-plugin-terser"

const banner = `
/*
Unobtrusive JavaScript
https://github.com/rails/rails/blob/main/actionview/app/javascript
Released under the MIT license
 */
`

const terserOptions = {
  mangle: false,
  compress: false,
  format: {
    beautify: true,
    indent_level: 2,
    comments: function (node, comment) {
      if (comment.type == "comment2") {
        // multiline comment
        return comment.value.includes("Released under the MIT license")
      }
    }
  }
}

export default [
  {
    input: "app/javascript/rails-ujs/index.js",
    output: {
      file: "app/assets/javascripts/rails-ujs.js",
      format: "umd",
      name: "Rails",
      banner,
    },
    plugins: [
      terser(terserOptions)
    ]
  },

  {
    input: "app/javascript/rails-ujs/index.js",
    output: {
      file: "app/assets/javascripts/rails-ujs.esm.js",
      format: "es",
      banner,
    },
    plugins: [
      terser(terserOptions)
    ]
  }
]
