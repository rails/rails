# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveSupport
  # Allows for configuration keys to be pulled from multiple backends. Keys are pulled in first-found order from
  # the configuration backends that the combined configuration has been initialized with.
  #
  # This is used by Rails to offer a unified API for fetching credentials from both ENV and the encrypted file.
  class CombinedConfiguration
    def initialize(*configurations)
      @configurations = configurations
    end

    # Find a upcased and double-underscored-joined string-version of the +keys+ in ENV.
    # Raises +KeyError+ if not found.
    #
    # Examples:
    #
    #   config.require(:db_host)         # => ENV.fetch("DB_HOST")
    #   config.require(:database, :host) # => ENV.fetch("DATABASE__HOST")
    def require(*keys)
      @configurations.each do |config|
        if value = config.option(*keys)
          return value
        end
      end

      raise KeyError, "Missing key: #{keys.inspect}"
    end

    # Find a upcased and double-underscored-joined string-version of the +keys+ in ENV.
    # Returns nil if the key isn't found or the value of the default block when passed.
    #
    # Examples:
    #
    #   config.option(:db_host)                             # => ENV["DB_HOST"]
    #   config.option(:database, :host)                     # => ENV["DATABASE__HOST"]
    #   config.option(:database, :host, default: "missing") # => ENV["DATABASE__HOST"]
    def option(*keys, default: nil)
      @configurations.each do |config|
        if value = config.option(*keys)
          return value
        end
      end

      default.respond_to?(:call) ? default.call : default
    end

    # Reload the cached values in any of the backend configurations.
    def reload
      @configurations.each { |config| config.try(:reload) }
    end
  end
end
