const path = require('path')

// NOTE: all NODE_ENV checks must be done in terms of 'production'

const dist = process.env.NODE_ENV === 'production'
  ? path.join(__dirname, './dist')
  : path.join(__dirname, '../public/dist')

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
          // TODO determine S3 path
          ? path.join(__dirname, '')
          : path.join(__dirname, '../../logic/runners/webapp/pkg'),
    },
  },
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
    ],
  },
  devtool: 'source-map',
}

