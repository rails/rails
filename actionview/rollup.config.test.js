// Rollup configuration for compiling the UJS tests

import commonjs from "@rollup/plugin-commonjs"
import resolve from "@rollup/plugin-node-resolve"

export default {
  input: "test/ujs/src/test.js",

  output: {
    file: "test/ujs/compiled/test.js",
    format: "iife"
  },

  plugins: [
    resolve(),
    commonjs()
  ]
}
