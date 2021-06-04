process.env.NODE_ENV = process.env.NODE_ENV || 'development'
const { environment } = require('@rails/webpacker')
module.exports = environment.toWebpackConfig()
