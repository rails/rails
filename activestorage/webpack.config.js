const path = require("path")

module.exports = {
  entry: {
    "activestorage": path.resolve(__dirname, "app/javascript/activestorage/index.js"),
  },

  output: {
    filename: "[name].js",
    path: path.resolve(__dirname, "app/assets/javascripts"),
    library: "ActiveStorage",
    libraryTarget: "umd"
  },

  devtool: "source-map",

  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader"
        }
      }
    ]
  }
}
