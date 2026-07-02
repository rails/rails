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
    input: "lib/passkeys/app/javascript/action_pack/index.js",
    output: {
      file: "lib/passkeys/app/assets/javascripts/actionpack-passkeys.js",
      format: "umd",
      name: "ActionPack"
    },
    plugins: [
      resolve(),
      terser(terserOptions)
    ]
  },

  {
    input: "lib/passkeys/app/javascript/action_pack/index.js",
    output: {
      file: "lib/passkeys/app/assets/javascripts/actionpack-passkeys.esm.js",
      format: "es"
    },
    plugins: [
      resolve(),
      terser(terserOptions)
    ]
  }
]
