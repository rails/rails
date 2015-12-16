# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

require 'action_cable/process/logging'

run Rails.application
