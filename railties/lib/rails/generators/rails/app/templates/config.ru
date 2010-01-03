# Require your environment file to bootstrap Rails
require ::File.expand_path('../config/environment',  __FILE__)

# Dispatch the request
run <%= app_const %>.instance
