const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const _ = require('lodash')

const path = require('path')

const dist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './dist')
    : path.join(__dirname, '../backend/public/dist')

const loaders = {
  js: {
    test: /\.js$/,
    exclude: /node_modules/,
    use: 'babel-loader',
  },
  css: {
    test: /\.(sa|sc|c)ss$/,
    use: [
      {
        loader: MiniCssExtractPlugin.loader,
        options: {
          hmr: process.env.HOT === '1',
        },
      },
      'css-loader',
      'sass-loader',
    ],
  },
  elm: (module) => ({
    test: /\.elm$/,
    exclude: [/elm-stuff/, /node_modules/],
    use: (process.env.HOT ? ['elm-hot-webpack-loader'] : []).concat([
      {
        loader: 'elm-webpack-loader',
        options: {
          optimize: process.env.NODE_ENV === 'production',
          cwd: path.join(__dirname, `./src/${module}`),
        },
      },
    ]),
  }),
  url: {
    test: /\.(woff|woff2|ttf)$/,
    use: 'file-loader',
  },
  raw: {
    test: /\.raw.*$/,
    use: 'raw-loader',
  },
  worker: {
    test: /wasi\.worker\.js$/,
    use: 'worker-loader',
  },
}

function mergeCustomizer(objValue, srcValue) {
  if (_.isArray(objValue)) {
    return objValue.concat(srcValue)
  }
}

function createConfigBase(dist, additional) {
  return _.mergeWith({
    mode: process.env.NODE_ENV || 'development',
    stats: 'minimal',
    output: {
      path: dist,
    },
    devtool: 'source-map',
    plugins: [
      new MiniCssExtractPlugin(),
    ],
  }, additional, mergeCustomizer)
}

function createDevServerConfig(base) {
  return {
    contentBase: base,
    historyApiFallback: true,
    stats: 'minimal',
    host: '0.0.0.0',
  }
}

module.exports = { dist, loaders, createConfigBase, createDevServerConfig }
