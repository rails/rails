import resolve from "@rollup/plugin-node-resolve"
import commonjs from "@rollup/plugin-commonjs"
import { terser } from "rollup-plugin-terser"
import pkg from "./package.json"

export default {
  input: pkg.module,
  output: {
    file: pkg.main,
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
