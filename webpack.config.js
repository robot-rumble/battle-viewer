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
      [`${module}_js`]: ['./src/polyfill.js', `./src/${module}/app.js`],
      [`${module}_css`]: `./src/${module}/main.scss`,
    },
    module: {
      rules: [
        loaders.js(module),
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
    site_js: './src/site/app.js',
    site_css: './src/site/main.scss',
  },
  module: {
    rules: [loaders.js('site'), loaders.css, loaders.file],
  },
})

module.exports = [siteConfig, createConfig('garage'), createConfig('battle')]
