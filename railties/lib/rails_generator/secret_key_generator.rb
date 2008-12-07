require 'active_support/deprecation'

module Rails
  # A class for creating random secret keys. This class will do its best to create a
  # random secret key that's as secure as possible, using whatever methods are
  # available on the current platform. For example:
  #
  #   generator = Rails::SecretKeyGenerator("some unique identifier, such as the application name")
  #   generator.generate_secret     # => "f3f1be90053fa851... (some long string)"
  #
  # This class is *deprecated* in Rails 2.2 in favor of ActiveSupport::SecureRandom.
  # It is currently a wrapper around ActiveSupport::SecureRandom.
  class SecretKeyGenerator
    def initialize(identifier)
    end

    # Generate a random secret key with the best possible method available on
    # the current platform.
    def generate_secret
      ActiveSupport::SecureRandom.hex(64)
    end
    deprecate :generate_secret=>"You should use ActiveSupport::SecureRandom.hex(64)"
  end
end
