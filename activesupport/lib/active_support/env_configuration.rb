# frozen_string_literal: true

# require "active_support/core_ext/module/delegation"

module ActiveSupport
  # Provide a better interface for accessing configuration options stored in ENV.
  # Keys are accepted as symbols and turned into upcased strings. Nesting is provided by double underscores.
  #
  # This interface mirrors what is used for +ActiveSupport::EncryptedConfiguration+ and thus allows both
  # to serve as interchangeable backends for +Rails.app.credentials+.
  #
  # Examples:
  #
  #   config = EnvConfiguration.new
  #   config[:db_host] # => ENV["DB_HOST"]
  #   config.dig(:database, :host) # => ENV["DATABASE__HOST"]
  class EnvConfiguration
    def initialize
      reload
    end

    # Find a upcased string-version of the +key+ in ENV.
    #
    # Example:
    #
    #   config[:db_host] # => ENV["DB_HOST"]
    def [](key)
      lookup envify(key)
    end

    # Find a upcased and double-underscored-joined string-version of the +keys+ in ENV.
    #
    # Examples:
    #
    #   config.dig(:db_host) # => ENV["DB_HOST"]
    #   config.dig(:database, :host) # => ENV["DATABASE__HOST"]
    def dig(*keys)
      lookup(keys.collect { |key| envify(key) }.join("__"))
    end

    # Reload the cached ENV values in case any of them changed or new ones were added during runtime.
    def reload
      @envs = ENV.to_h
    end

    private
      def lookup(env_key)
        @envs[env_key]
      end

      def envify(key)
        key.to_s.upcase
      end
  end
end
