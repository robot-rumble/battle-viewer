const webpack = require('webpack')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')

const { createConfigBase, loaders } = require('./webpack.common.js')

function createConfig (module) {
  return createConfigBase({
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
  })
}

const siteConfig = createConfigBase({
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
