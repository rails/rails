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

    private
      def lookup(env_key)
        ENV[env_key]
      end

      def envify(key)
        key.to_s.upcase
      end
  end
end
