require File.dirname(__FILE__) + '/config/environment'
use Rails::Rack::Static
run ActionController::Dispatcher.new
