const path = require('path')
const CopyPlugin = require('copy-webpack-plugin')

const { dist, createConfigBase, loaders } = require('./webpack.common.js')

const logicWasmDist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './wasm-dist')
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
      logic: path.join(logicWasmDist, 'browser-runner'),
    },
  },
  plugins: process.env.NODE_ENV !== 'production'
    ? [new CopyPlugin([{ from: path.join(logicWasmDist, 'lang-runners'), to: dist }])]
    : [],
})
