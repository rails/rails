# Require your environment file to bootstrap Rails
require ::File.dirname(__FILE__) + '/config/environment'

# Dispatch the request
run Rails.application.new
