# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'
Rails.application.load_forkers

run Rails.application
