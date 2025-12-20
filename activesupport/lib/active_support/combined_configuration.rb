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

    # Find singular or nested keys across all backends. If no backend holds the key, it raises +KeyError+.
    #
    # Examples of Rails-configured access:
    #
    #   require(:db_host)         # => ENV.fetch("DB_HOST") || Rails.app.credentials.require(:db_host)
    #   require(:database, :host) # => ENV.fetch("DATABASE__HOST") || Rails.app.credentials.require(:database, :host)
    def require(*key)
      @configurations.each do |config|
        if value = config.option(*key)
          return value
        end
      end

      raise KeyError, "Missing key: #{key.inspect}"
    end

    # Find singular or nested keys across all backends. If no backend holds the key, +nil+ is returned.
    # If a +default+ value is defined, it (or its callable value) will be returned on a missing key.
    #
    # Examples:
    #
    #   option(:db_host)                             # => ENV["DB_HOST"] || Rails.app.credentials.option(:db_host)
    #   option(:database, :host)                     # => ENV["DATABASE__HOST"] || Rails.app.credentials.option(:database, :host)
    #   option(:database, :host, default: "missing") # => ENV["DATABASE__HOST"] || Rails.app.credentials.option(:database, :host) || "missing"
    #   option(:database, :host, default: -> { "missing" }) # => ENV["DATABASE__HOST"] || Rails.app.credentials.option(:database, :host) || "missing"
    def option(*key, default: nil)
      @configurations.each do |config|
        if value = config.option(*key)
          return value
        end
      end

      default.respond_to?(:call) ? default.call : default
    end

    # Reload the cached values for all of the backend configurations.
    def reload
      @configurations.each { |config| config.try(:reload) }
    end
  end
end
