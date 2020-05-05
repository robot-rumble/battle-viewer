const path = require('path')
const CopyPlugin = require('copy-webpack-plugin')

// NOTE: all NODE_ENV checks must be done in terms of 'production'

const dist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './dist')
    : path.join(__dirname, '../public/dist')

const logicDist =
  process.env.NODE_ENV === 'production'
    ? null
    : path.join(__dirname, '../../logic/webapp-dist/')

module.exports = {
  mode: process.env.NODE_ENV || 'development',
  stats: 'minimal',
  entry: ['@babel/polyfill', './src/match.worker.js'],
  target: 'webworker',
  output: {
    path: dist,
    filename: 'worker.js',
  },
  resolve: {
    alias: {
      logic:
        process.env.NODE_ENV === 'production'
          ? // TODO determine S3 path
            path.join(__dirname, '')
          : logicDist + 'logic',
    },
  },
  plugins: [new CopyPlugin([{ from: logicDist + 'runners', to: dist }])],
  node: {
    fs: 'empty',
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: { loader: 'babel-loader' },
      },
      {
        test: /\.raw.*$/,
        use: 'raw-loader',
      },
      {
        test: /wasi\.worker\.js$/,
        use: 'worker-loader',
      },
    ],
  },
  devtool: 'source-map',
}
