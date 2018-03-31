const path = require("path")
const webpack = require("webpack")
const ExtractTextPlugin = require("extract-text-webpack-plugin")

module.exports = {
  entry: {
    main: path.resolve(__dirname, "./src/index.js"),
  },

  output: {
    filename: "[name].js",
    path: path.resolve(__dirname, "./assets/packs"),
  },

  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
        }
      },
      {
        test: /\.scss/,
        use: ExtractTextPlugin.extract({
          use: [
            "css-loader",
            "sass-loader",
          ]
        }),
      },
      {
        test: /\.(gif|png|jpg|eot|wof|woff|woff2|ttf|svg)$/,
        use: {
          loader: "url-loader",
          options: {
            limit: 8192,
            name: './images/[name].[ext]'
          }
        }
      }
    ]
  },

  plugins: [
    new ExtractTextPlugin("style.css"),
    new webpack.ProvidePlugin({
      $: "jquery",
    }),
  ]
}
