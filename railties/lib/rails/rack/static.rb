require 'action_dispatch'

module Rails::Rack
  Static = Deprecation::DeprecatedConstantProxy.new('Rails::Rack::Static', ActionDispatch::Static)
end
