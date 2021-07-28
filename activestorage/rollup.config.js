import resolve from "@rollup/plugin-node-resolve"
import commonjs from "@rollup/plugin-commonjs"
import { terser } from "rollup-plugin-terser"

export default [
  {
    input: "app/javascript/activestorage/index.js",
    output: {
      file: "app/assets/javascripts/activestorage.js",
      format: "umd",
      name: "ActiveStorage"
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
  },

  {
    input: "app/javascript/activestorage/index.js",
    output: {
      file: "app/assets/javascripts/activestorage.esm.js",
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
]
