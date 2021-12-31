import resolve from "@rollup/plugin-node-resolve"
import commonjs from "@rollup/plugin-commonjs"

export default {
  input: "app/javascript/actiontext/index.js",
  output: {
    file: "app/assets/javascripts/actiontext.js",
    format: "es"
  },
  plugins: [
    resolve(),
    commonjs()
  ]
}
