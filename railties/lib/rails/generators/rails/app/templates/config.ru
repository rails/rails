# Require your environment file to bootstrap Rails
require File.expand_path('../config/application',  __FILE__)

# Dispatch the request
run Rails.application.new
