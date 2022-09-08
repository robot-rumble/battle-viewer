const webpack = require('webpack')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const _ = require('lodash')

const path = require('path')

const dist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './dist')
    : path.join(__dirname, '../backend/public/dist')

const babelPresetEnv = (browserslistEnv) => [
  '@babel/preset-env',
  {
    useBuiltIns: 'entry',
    corejs: 3,
    browserslistEnv,
  },
]

const loaders = {
  js: (module) => ({
    test: /\.js$/,
    exclude: /node_modules/,
    use: {
      loader: 'babel-loader',
      options: {
        cacheDirectory: true,
        presets: [babelPresetEnv(module)],
      },
    },
  }),
  ts: (module) => ({
    test: /\.tsx?$/,
    exclude: /node_modules/,
    use: [
      {
        loader: 'babel-loader',
        options: {
          cacheDirectory: true,
          presets: [babelPresetEnv(module), 'solid'],
        },
      },
      'ts-loader',
    ],
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
    type: 'asset/resource',
  },
  url: {
    test: /\.svg$/,
    type: 'asset/inline',
  },
}

function mergeCustomizer(objValue, srcValue) {
  if (_.isArray(objValue)) {
    return objValue.concat(srcValue)
  }
}

function createConfigBase(dist, additional) {
  const common = {
    target: 'web',
    mode: process.env.NODE_ENV || 'development',
    stats: 'minimal',
    output: {
      publicPath: 'auto',
      path: dist,
    },
    resolve: {
      extensions: ['.ts', '.tsx', '.js'],
    },
    devtool: 'source-map',
    plugins: [
      new MiniCssExtractPlugin(),
      new webpack.EnvironmentPlugin({
        NODE_ENV: 'development',
        BOT_LANG: process.env.BOT_LANG || 'Python',
        SENTRY_DSN: process.env.SENTRY_DSN || null,
        TUTORIAL_URL: process.env.TUTORIAL_URL || null,
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
    static: {
      directory: base,
    },
    historyApiFallback: true,
    host: '0.0.0.0',
  }
}

module.exports = {
  dist,
  loaders,
  createConfigBase,
  createDevServerConfig,
}
