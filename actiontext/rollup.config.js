import resolve from "@rollup/plugin-node-resolve"
import commonjs from "@rollup/plugin-commonjs"
import { terser } from "rollup-plugin-terser"
import pkg from "./package.json"

export default {
  input: pkg.main,
  output: {
    file: "app/assets/javascripts/action_text.js",
    format: "es"
  },
  plugins: [
    resolve(),
    commonjs(),
    terser({
      mangle: false,
      compress: false,
      format: {
        beautify: true,
        indent_level: 2
      }
    })
  ]
}
