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

    # Combined interface for #[] and #dig. Examples:
    #
    #   creds.grab(:db_host) # => creds[:db_host]
    #   creds.grab(:database, :host) # => creds.dig(:database, :host)
    def grab(*keys)
      if keys.many?
        dig(*keys)
      else
        self[keys.first]
      end
    end

    # Retrieve the value from the first configuration backend that holds it.
    def [](key)
      @configurations.each do |config|
        if value = config[key]
          return value
        end
      end
    end

    # Retrieve the nested value from the first configuration backend that holds it.
    def dig(*keys)
      @configurations.find do |config|
        if value = config.dig(*keys)
          return value
        end
      end
    end
  end
end
