const path = require('path')
const webpack = require('webpack')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')

// NOTE: all NODE_ENV checks must be done in terms of 'production'

const dist = process.env.NODE_ENV === 'production'
  ? path.join(__dirname, './dist')
  : path.join(__dirname, '../public/dist')

module.exports = {
  mode: process.env.NODE_ENV || 'development',
  stats: 'minimal',
  entry: {
    webapp_js: ['@babel/polyfill', './src/app.js'],
    webapp_css: './src/css/webapp.scss',
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
        use: (process.env.HOT ? ['elm-hot-webpack-loader'] : []).concat([{
          loader: 'elm-webpack-loader',
          options: {
            optimize: process.env.NODE_ENV === 'production',
          },
        }]),
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
