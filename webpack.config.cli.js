const path = require('path')

const HtmlWebpackPlugin = require('html-webpack-plugin')
const CopyWebpackPlugin = require('copy-webpack-plugin')

const { createConfigBase, loaders } = require('./webpack.common.js')

const dist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './cli-dist')
    : path.join(__dirname, '../cli/dist')

module.exports = createConfigBase(dist, {
  entry: './src/cli/app.js',
  module: {
    rules: [
      loaders.js(),
      loaders.css,
      loaders.elm('cli'),
      loaders.file,
      loaders.url,
    ],
  },
  plugins: [
    new HtmlWebpackPlugin({ template: 'src/cli/index.html' }),
    new CopyWebpackPlugin({
      patterns: [
        {
          from:
            process.env.NODE_ENV === 'production'
              ? path.join(__dirname, './images')
              : path.join(__dirname, '../backend/public/images'),
          to: path.join(dist, 'images'),
        },
      ],
    }),
  ],
})
