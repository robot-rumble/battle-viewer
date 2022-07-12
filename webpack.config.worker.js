const path = require('path')
const CopyPlugin = require('copy-webpack-plugin')

const {
  createConfigBase,
  loaders,
} = require('./webpack.common.js')

const dist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './worker-dist')
    : path.join(__dirname, '../backend/public/dist')

const logicWasmDist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './wasm-dist')
    : path.join(__dirname, '../logic/wasm-dist/')

module.exports = createConfigBase(dist, {
  entry: {
    worker: ['./src/polyfill.js', './src/garage/match.worker.js'],
  },
  target: 'webworker',
  module: {
    rules: [loaders.js('worker')],
  },
  resolve: {
    alias: {
      logic: path.join(logicWasmDist, 'browser-runner'),
    },
  },
  plugins:
    process.env.NODE_ENV !== 'production'
      ? [
        new CopyPlugin({
          patterns: [
            {
              from: path.join(logicWasmDist, 'lang-runners'),
              to: dist,
            },
          ],
        }),
      ]
      : [],
})
