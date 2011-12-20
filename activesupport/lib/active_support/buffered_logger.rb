require 'thread'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/deprecation'
require 'active_support/logger'
require 'fileutils'

module ActiveSupport
  BufferedLogger = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
    'BufferedLogger', '::ActiveSupport::Logger')
end
