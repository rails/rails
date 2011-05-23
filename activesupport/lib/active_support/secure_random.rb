require 'active_support/deprecation'

module ActiveSupport
  # Use Ruby's SecureRandom library.
  SecureRandom = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('ActiveSupport::SecureRandom', ::SecureRandom) # :nodoc:
end
