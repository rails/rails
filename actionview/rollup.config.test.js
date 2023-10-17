// Rollup configuration for compiling the UJS tests

import commonjs from "@rollup/plugin-commonjs"
import replace from "@rollup/plugin-replace"
import resolve from "@rollup/plugin-node-resolve"

export default {
  input: "test/ujs/src/test.js",

  output: {
    file: "test/ujs/compiled/test.js",
    format: "iife"
  },

  plugins: [
    replace({
      preventAssignment: true,
      values: { __esm: false }, // false because the tests expects start() to be called automatically
    }),
    resolve(),
    commonjs()
  ]
}
