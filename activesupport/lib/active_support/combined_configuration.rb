# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveSupport
  # Allows for configuration keys to be pulled from multiple backends. Keys are pulled in first-found order from
  # the configuration backends that the combined configuration has been initialized with.
  #
  # This is used by Rails to offer a unified API for fetching credentials from both ENV and the encrypted file.
  # You can access this through +Rails.app.creds+ within a Rails application.
  class CombinedConfiguration
    def initialize(*configurations)
      @configurations = configurations
    end

    # Find singular or nested keys across all backends.
    # Raises +KeyError+ if no backend holds the key or if the value is nil.
    #
    # Given ENV:
    #   DB_HOST: "env.example.com"
    #   DATABASE__HOST: "env.example.com"
    #
    # And credentials:
    #   database:
    #     host: "creds.example.com"
    #   api_key: "secret"
    #   api_host: null
    #
    # Examples:
    #   require(:db_host)         # => "env.example.com" (from ENV)
    #   require(:database, :host) # => "env.example.com" (ENV overrides credentials)
    #   require(:api_key)         # => "secret" (from credentials)
    #   require(:missing)         # => KeyError
    #   require(:api_host)        # => KeyError (nil values are treated as missing)
    def require(*key)
      @configurations.each do |config|
        value = config.option(*key)
        return value unless value.nil?
      end

      raise KeyError, "Missing key: #{key.inspect}"
    end

    # Find singular or nested keys across all backends.
    # Returns +nil+ if no backend holds the key.
    # If a +default+ value is defined, it (or its callable value) will be returned on a missing key.
    #
    # Given ENV:
    #   DB_HOST: "env.example.com"
    #   DATABASE__HOST: "env.example.com"
    #
    # And credentials:
    #   database:
    #     host: "creds.example.com"
    #   api_key: "secret"
    #   api_host: null
    #
    # Examples:
    #   option(:db_host)                              # => "env.example.com" (from ENV)
    #   option(:database, :host)                      # => "env.example.com" (ENV overrides credentials)
    #   option(:api_key)                              # => "secret" (from credentials)
    #   option(:missing)                              # => nil
    #   option(:missing, default: "localhost")        # => "localhost"
    #   option(:missing, default: -> { "localhost" }) # => "localhost"
    #   option(:api_host, default: "api.example.com") # => "api.example.com" (nil values use default)
    def option(*key, default: nil)
      @configurations.each do |config|
        value = config.option(*key)
        return value unless value.nil?
      end

      default.respond_to?(:call) ? default.call : default
    end

    # Reload the cached values for all of the backend configurations.
    def reload
      @configurations.each { |config| config.try(:reload) }
    end
  end
end
