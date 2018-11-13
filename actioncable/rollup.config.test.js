import babel from "rollup-plugin-babel"

export default {
  input: "test/javascript/src/test.js",

  output: {
    file: "test/javascript/compiled/test.js",
    format: "iife"
  },

  plugins: [
    babel()
  ]
}
