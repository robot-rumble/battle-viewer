const path = require('path')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')

const dist = process.env.NODE_ENV === 'production'
  ? path.join(__dirname, './dist')
  : path.join(__dirname, '../../public/dist')

const browserConfig = {
  mode: process.env.NODE_ENV || 'development',
  stats: 'minimal',
  entry: {
    app: ['@babel/polyfill', './src/app.js'],
  },
  output: {
    path: dist,
    filename: 'bundle.js',
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: { loader: 'babel-loader' },
      },
      {
        test: /\.(sa|sc|c)ss$/,
        use: [
          process.env.NODE_ENV === 'production' ? MiniCssExtractPlugin.loader : 'style-loader',
          'css-loader',
          'sass-loader',
        ],
      },
      {
        test: /\.elm$/,
        use: {
          loader: 'elm-webpack-loader',
          options: {
            optimize: process.env.NODE_ENV === 'production',
          },
        },
      },
      {
        test: /\.(woff|ttf)$/,
        use: [
          {
            loader: 'url-loader',
          },
        ],
      },
      {
        test: /\.raw.*$/,
        use: 'raw-loader',
      },
    ],
  },
  plugins: [new MiniCssExtractPlugin()],
  devServer: {
    contentBase: dist,
    historyApiFallback: true,
    stats: 'minimal',
    host: '0.0.0.0',
  },
  devtool: 'source-map'
}

const workerConfig = {
  mode: process.env.NODE_ENV || 'development',
  stats: 'minimal',
  entry: ['@babel/polyfill', './src/match.worker.js'],
  target: 'webworker',
  output: {
    path: dist,
    filename: 'worker.js',
  },
  resolve: {
    alias: {
      logic:
        process.env.NODE_ENV === 'production'
          ? './frontend.js'
          : process.env.DOCKER
          ? '/logic/_build'
          : path.join(__dirname, '../logic/_build/default/frontend.js'),
    },
  },
  node: {
    fs: 'empty',
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: { loader: 'babel-loader' },
      },
      {
        test: /\.raw.*$/,
        use: 'raw-loader',
      },
    ],
  },
  devtool: 'source-map'
}

module.exports = [browserConfig, workerConfig]
