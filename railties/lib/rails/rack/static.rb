require 'action_dispatch'

module Rails::Rack
  Static = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('Rails::Rack::Static', ActionDispatch::Static)
end
