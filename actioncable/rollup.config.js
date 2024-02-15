import resolve from "@rollup/plugin-node-resolve"
import { terser } from "rollup-plugin-terser"

const terserOptions = {
  mangle: false,
  compress: false,
  format: {
    beautify: true,
    indent_level: 2
  }
}

export default [
  {
    input: "app/javascript/action_cable/index.js",
    output: [
      {
        file: "app/assets/javascripts/actioncable.js",
        format: "umd",
        name: "ActionCable"
      },

      {
        file: "app/assets/javascripts/actioncable.esm.js",
        format: "es"
      }
    ],
    plugins: [
      resolve(),
      terser(terserOptions)
    ]
  },

  {
    input: "app/javascript/action_cable/index_with_name_deprecation.js",
    output: {
      file: "app/assets/javascripts/action_cable.js",
      format: "umd",
      name: "ActionCable"
    },
    plugins: [
      resolve(),
      terser(terserOptions)
    ]
  },
]
