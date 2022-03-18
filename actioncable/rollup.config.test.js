import commonjs from "@rollup/plugin-commonjs"
import resolve from "@rollup/plugin-node-resolve"

export default {
  input: "test/javascript/src/test.js",

  output: {
    file: "test/javascript/compiled/test.js",
    format: "iife"
  },

  plugins: [
    resolve(),
    commonjs()
  ]
}
