var ExtractTextPlugin = require('extract-text-webpack-plugin')
const path = require('path')

module.exports = {
  entry: ['./src/js/entry', './src/scss/app.scss'],
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'my-app.js'
  },
  watch: true,
  module: {
    loaders: [
      {
        test: /\.css$/,
        loader: ExtractTextPlugin.extract({
          loader: 'css-loader?importLoaders=1'
        })
      },
      {
        test: /\.(sass|scss)$/,
        loader: ExtractTextPlugin.extract(['css-loader', 'sass-loader'])
      },
      {
        test: /\.json$/,
        loader: 'json-loader'
      }
    ]
  },
  plugins: [
    new ExtractTextPlugin({
      filename: 'my-app.css',
      allChunks: true
    })
  ]
}
