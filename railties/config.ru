# Rackup Configuration
#
# Start Rails mongrel server with rackup
# $ rackup -p 3000 config.ru
#
# Start server with webrick (or any compatible Rack server) instead
# $ rackup -p 3000 -s webrick config.ru

# Require your environment file to bootstrap Rails
require File.dirname(__FILE__) + '/config/environment'

# Static server middleware
# You can remove this extra check if you use an asset server
use Rails::Rack::Static

# Dispatch the request
run ActionController::Dispatcher.new
