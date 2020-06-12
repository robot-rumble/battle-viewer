const path = require('path')
const webpack = require('webpack')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')

const { createConfigBase, createDevServerConfig, loaders, dist } = require('./webpack.common.js')

function createConfig (module) {
  return createConfigBase(dist, {
    name: module,
    entry: {
      [`${module}_js`]: ['@babel/polyfill', `./src/${module}/app.js`],
      [`${module}_css`]: `./src/${module}/main.scss`,
    },
    module: {
      rules: [
        loaders.js,
        loaders.css,
        loaders.elm(module),
        loaders.raw,
        loaders.url,
      ],
    },
    plugins: [
      new MiniCssExtractPlugin(),
      new webpack.EnvironmentPlugin({
        NODE_ENV: 'development',
      }),
    ],
    devServer: createDevServerConfig(path.join(__dirname, '../backend/public')),
  })
}

const siteConfig = createConfigBase(dist, {
  entry: {
    site_css: './src/site/main.scss',
  },
  module: {
    rules: [
      loaders.css,
      loaders.url,
    ],
  },
  plugins: [new MiniCssExtractPlugin()],
})

module.exports = [siteConfig, createConfig('garage'), createConfig('battle')]
