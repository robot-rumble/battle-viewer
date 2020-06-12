const path = require('path')
const CopyPlugin = require('copy-webpack-plugin')

const { dist, createConfigBase, loaders } = require('./webpack.common.js')

const logicDist =
  process.env.NODE_ENV === 'production'
    ? null
    : path.join(__dirname, '../logic/webapp-dist/')

module.exports = createConfigBase({
  entry: {
    worker: ['@babel/polyfill', './src/garage/match.worker.js']
  },
  target: 'webworker',
  node: {
    fs: 'empty',
  },
  module: {
    rules: [
      loaders.js,
      loaders.raw,
      loaders.worker
    ],
  },
  resolve: {
    alias: {
      logic: logicDist + 'logic',
    },
  },
  plugins: [new CopyPlugin([{ from: logicDist + 'runners', to: dist }])],
})
