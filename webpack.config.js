const path = require('path')

const {
  createConfigBase,
  createDevServerConfig,
  loaders,
  dist,
} = require('./webpack.common.js')

function createConfig(module) {
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
        loaders.file,
        loaders.url,
      ],
    },
    devServer: createDevServerConfig(path.join(__dirname, '../backend/public')),
  })
}

const siteConfig = createConfigBase(dist, {
  name: 'site',
  entry: {
    site_css: './src/site/main.scss',
  },
  module: {
    rules: [loaders.css, loaders.file],
  },
})

const baseConfig = createConfigBase(dist, {
  name: 'base',
  entry: {
    base_js: './src/base/app.js',
  },
  module: {
    rules: [loaders.js],
  },
})

module.exports = [siteConfig, baseConfig, createConfig('garage'), createConfig('battle')]
