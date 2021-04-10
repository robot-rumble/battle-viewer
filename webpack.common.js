const webpack = require('webpack')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const _ = require('lodash')

const path = require('path')

const dist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './dist')
    : path.join(__dirname, '../backend/public/dist')

const loaders = {
  js: (browserslistEnv) => ({
    test: /\.js$/,
    exclude: /node_modules/,
    use: {
      loader: 'babel-loader',
      options: {
        presets: [
          [
            '@babel/preset-env',
            { useBuiltIns: 'entry', corejs: 3, browserslistEnv },
          ],
        ],
      },
    },
  }),
  css: {
    test: /\.(sa|sc|c)ss$/,
    use: [MiniCssExtractPlugin.loader, 'css-loader', 'sass-loader'],
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
          debug: false,
        },
      },
    ]),
  }),
  file: {
    test: /\.(woff|woff2|ttf)$/,
    use: 'file-loader',
  },
  url: {
    test: /\.svg$/,
    use: 'url-loader',
  },
}

function mergeCustomizer(objValue, srcValue) {
  if (_.isArray(objValue)) {
    return objValue.concat(srcValue)
  }
}

function createConfigBase(dist, additional) {
  const common = {
    mode: process.env.NODE_ENV || 'development',
    stats: 'minimal',
    output: {
      publicPath: 'auto',
      path: dist,
    },
    devtool: 'source-map',
    plugins: [
      new MiniCssExtractPlugin(),
      new webpack.EnvironmentPlugin({
        NODE_ENV: 'development',
        BOT_LANG: process.env.BOT_LANG || 'Python',
        SENTRY_DSN: process.env.SENTRY_DSN,
      }),
    ],
    experiments: {
      asyncWebAssembly: true,
    },
  }
  return _.mergeWith(common, additional, mergeCustomizer)
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
