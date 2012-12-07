require 'active_support/deprecation'

module ActiveSupport
  # :nodoc:
  # Deprecated in favor of ActiveSupport::ProxyObject
  BasicObject = Deprecation::DeprecatedConstantProxy.new('ActiveSupport::BasicObject', 'ActiveSupport::ProxyObject')
end
