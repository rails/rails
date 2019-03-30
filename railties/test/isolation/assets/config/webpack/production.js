process.env.NODE_ENV = process.env.NODE_ENV || 'production'
const { environment } = require('@rails/webpacker')
module.exports = environment.toWebpackConfig()
