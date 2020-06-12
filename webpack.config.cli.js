const path = require('path')

const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const HtmlWebpackPlugin = require('html-webpack-plugin')
const CopyWebpackPlugin = require('copy-webpack-plugin')

const { createConfigBase, loaders } = require('./webpack.common.js')

const dist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './dist')
    : path.join(__dirname, '../cli/dist')

module.exports = createConfigBase({
  entry: './src/cli/app.js',
  module: {
    rules: [
      loaders.js,
      loaders.css,
      loaders.elm('cli'),
      loaders.raw,
      loaders.url,
    ],
  },
  plugins: [
    new MiniCssExtractPlugin(),
    new HtmlWebpackPlugin({ template: 'src/cli/index.html' }),
    new CopyWebpackPlugin([
      {
        from: path.resolve(__dirname, '../backend/public/images'),
        to: 'images',
      },
    ]),
  ],
  output: {
    path: dist,
  },
})
