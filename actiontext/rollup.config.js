import resolve from "@rollup/plugin-node-resolve"
import commonjs from "@rollup/plugin-commonjs"

export default [  
  {
    input: "app/javascript/actiontext/index.js",
    output: {
      file: "app/assets/javascripts/action_text.js",
      format: "es"
    },
    plugins: [
      resolve(),
      commonjs()
    ]
  },

  {
    input: "app/javascript/trix/mirror.js",
    output: {
      file: "app/assets/javascripts/trix.js",
      format: "es"
    },
    plugins: [
      resolve()
    ]
  }
]
