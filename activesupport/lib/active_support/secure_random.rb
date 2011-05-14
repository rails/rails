require 'securerandom'

module ActiveSupport
  # Use Ruby's SecureRandom library.
  SecureRandom = ::SecureRandom # :nodoc:
end
