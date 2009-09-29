# Rack Dispatcher

# Bootstrap rails
require ::File.dirname(__FILE__) + '/config/boot'
# Require your environment file to bootstrap Rails

# Dispatch the request
run Rails::Application.load(::File.dirname(__FILE__) + '/config/environment.rb')
