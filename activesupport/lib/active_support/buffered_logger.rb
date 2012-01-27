require 'active_support/deprecation'
require 'active_support/logger'

module ActiveSupport
  BufferedLogger = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
    'BufferedLogger', '::ActiveSupport::Logger')
end
