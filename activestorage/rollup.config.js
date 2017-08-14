const { resolve } = require('path')
const babel = require('rollup-plugin-babel')
const cjs = require('rollup-plugin-commonjs')
const nodeResolvePlugin = require('rollup-plugin-node-resolve')
const uglify = require('rollup-plugin-uglify')
const { main } = require('./package.json')

module.exports = {
  entry: resolve("app/javascript/activestorage/index.js"),
  dest: resolve(main),
  format: 'umd',
  context: 'window',
  moduleName: 'ActiveStorage',
  plugins: [
    nodeResolvePlugin({ jsnext: true, module: true, main: true, browser: true }),
    babel({ exclude: 'node_modules/**' }),
    cjs({}),
    uglify()
  ]
}
