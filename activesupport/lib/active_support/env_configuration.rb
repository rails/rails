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
  #   require(:db_host)                                   # => ENV.fetch("DB_HOST")
  #   require(:database, :host)                           # => ENV.fetch("DATABASE__HOST")
  #   option(:database, :host)                            # => ENV["DATABASE__HOST"]
  #   option(:debug, default: "true")                     # => ENV.fetch("DB_HOST") { "true" }
  #   option(:database, :host, default: -> { "missing" }) # => ENV.fetch("DATABASE__HOST") { default.call }
  class EnvConfiguration
    def initialize
      reload
    end

    # Find an upcased and double-underscored-joined string-version of the +key+ in ENV.
    # Raises +KeyError+ if not found.
    #
    # Examples:
    #
    #   require(:db_host)         # => ENV.fetch("DB_HOST")
    #   require(:database, :host) # => ENV.fetch("DATABASE__HOST")
    def require(*key)
      @envs.fetch envify(*key)
    end

    # Find an upcased and double-underscored-joined string-version of the +key+ in ENV.
    # Returns +nil+ if the key isn't found or the value of +default+ when passed.
    # If +default+ is a callable, it's called first.
    #
    # Examples:
    #
    #   option(:db_host)                                    # => ENV["DB_HOST"]
    #   option(:database, :host)                            # => ENV["DATABASE__HOST"]
    #   option(:database, :host, default: "missing")        # => ENV.fetch("DATABASE__HOST", "missing")
    #   option(:database, :host, default: -> { "missing" }) # => ENV.fetch("DATABASE__HOST") { default.call }
    def option(*key, default: nil)
      if default.respond_to?(:call)
        @envs.fetch(envify(*key)) { default.call }
      else
        @envs.fetch envify(*key), default
      end
    end

    # Reload the cached ENV values in case any of them changed or new ones were added during runtime.
    def reload
      @envs = ENV.to_h
    end

    # Returns an array of symbolized keys from the environment variables.
    #
    # Examples:
    #
    #   ENV["DB_HOST"] = "localhost"
    #   ENV["DATABASE_PORT"] = "5432"
    #
    #   env_config = ActiveSupport::EnvConfiguration.new
    #   env_config.keys
    #   # => [:db_host, :database_port, ...]
    #
    def keys
      @envs.keys.map { |k| k.downcase.to_sym }
    end

    def inspect # :nodoc:
      "#<#{self.class.name}:#{'%#016x' % (object_id << 1)} keys=#{keys.inspect}>"
    end

    private
      def lookup(env_key)
        @envs[env_key]
      end

      def envify(*key)
        key.collect { |part| part.to_s.upcase }.join("__")
      end
  end
end
