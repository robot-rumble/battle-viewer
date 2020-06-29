const path = require('path')
const CopyPlugin = require('copy-webpack-plugin')

const { dist, createConfigBase, loaders } = require('./webpack.common.js')

const logicWasmDist =
  process.env.NODE_ENV === 'production'
    ? null
    : path.join(__dirname, '../logic/wasm-dist/')

module.exports = createConfigBase(dist, {
  entry: {
    worker: ['@babel/polyfill', './src/garage/match.worker.js'],
  },
  target: 'webworker',
  node: {
    fs: 'empty',
  },
  module: {
    rules: [loaders.js, loaders.raw, loaders.worker],
  },
  resolve: {
    alias: {
      logic: logicWasmDist + 'browser-runner',
    },
  },
  plugins: [new CopyPlugin([{ from: logicWasmDist + 'lang-runners', to: dist }])],
})
