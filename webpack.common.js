const MiniCssExtractPlugin = require('mini-css-extract-plugin')
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
    test: /\.(woff|ttf)$/,
    use: 'url-loader',
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

function createConfigBase (additional) {
  return {
    mode: process.env.NODE_ENV || 'development',
    stats: 'minimal',
    output: {
      path: dist,
    },
    devServer: {
      contentBase: '../backend/public',
      historyApiFallback: true,
      stats: 'minimal',
      host: '0.0.0.0',
    },
    devtool: 'source-map',
    ...additional,
  }
}

module.exports = { dist, loaders, createConfigBase }
