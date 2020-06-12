const path = require('path')
const webpack = require('webpack')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')

// NOTE: all NODE_ENV checks must be done in terms of 'production'

const dist =
  process.env.NODE_ENV === 'production'
    ? path.join(__dirname, './dist')
    : path.join(__dirname, '../public/dist')

const battleViewer = path.join(__dirname, '../../battle-viewer')

const mainConfig = {
  mode: process.env.NODE_ENV || 'development',
  stats: 'minimal',
  entry: {
    garage_js: ['@babel/polyfill', './src/garage/app.js'],
    garage_css: './src/garage/main.scss',
    site_css: './src/css/site.scss',
  },
  output: {
    path: dist,
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
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: (process.env.HOT ? ['elm-hot-webpack-loader'] : []).concat([
          {
            loader: 'elm-webpack-loader',
            options: {
              optimize: process.env.NODE_ENV === 'production',
              cwd: path.join(__dirname, './src/garage'),
            },
          },
        ]),
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
  resolve: {
    alias: {
      'battle-viewer': battleViewer,
    },
  },
  plugins: [
    new MiniCssExtractPlugin(),
    new webpack.EnvironmentPlugin({
      NODE_ENV: 'development',
    }),
  ],
  devServer: {
    contentBase: '../public',
    historyApiFallback: true,
    stats: 'minimal',
    host: '0.0.0.0',
  },
  devtool: 'source-map',
}

const battleConfig = {
  mode: process.env.NODE_ENV || 'development',
  stats: 'minimal',
  entry: {
    battle_js: ['@babel/polyfill', './src/battle/app.js'],
    battle_css: './src/battle/main.scss',
  },
  output: {
    path: dist,
  },
  module: {
    rules: [
      {
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
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: { loader: 'babel-loader' },
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: {
          loader: 'elm-webpack-loader',
          options: {
            optimize: process.env.NODE_ENV === 'production',
            cwd: path.join(__dirname, './src/battle'),
          },
        },
      },
    ],
  },
  resolve: {
    alias: {
      'battle-viewer': battleViewer,
    },
  },
  plugins: [new MiniCssExtractPlugin()],
  devtool: 'source-map',
}

module.exports = [mainConfig, battleConfig]
