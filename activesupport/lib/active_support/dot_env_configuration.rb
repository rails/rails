# frozen_string_literal: true

require "active_support/env_configuration"

module ActiveSupport
  # Provide an interface for accessing configuration options stored in a .env file.
  # Keys are accepted as symbols and turned into upcased strings. Nesting is provided by double underscores.
  #
  # This interface mirrors what is used for +ActiveSupport::EnvConfiguration+ and +ActiveSupport::EncryptedConfiguration+
  # and thus allows all three to serve as interchangeable backends for +Rails.app.creds+.
  #
  # The .env file format supports:
  # - Lines with KEY=value pairs
  # - Comments starting with #
  # - Empty lines (ignored)
  # - Quoted values (single or double quotes)
  # - Variable interpolation with ${VAR} syntax
  # - Command execution with $(command) syntax
  #
  # The command execution allows for easy integration with third-party credential providers, like 1password:
  #
  #   DB_HOST=$(op read op://Vault/item/value --account=MyAccount)
  #
  # When used inside Rails, the default path for the .env file will be `Rails.root.join(".env")`.
  # Otherwise it must be passed in as +path+.
  #
  # Examples:
  #
  #   require(:db_host)                                   # => value of DB_HOST from .env
  #   require(:database, :host)                           # => value of DATABASE__HOST from .env
  #   option(:debug)                                      # => value of DEBUG from .env or nil if missing
  #   option(:debug, default: "true")                     # => value of DEBUG from .env or "true" if not found
  #   option(:database, :host, default: -> { "missing" }) # => value of DATABASE__HOST from .env or "missing" if not found
  class DotEnvConfiguration < EnvConfiguration
    def initialize(path)
      @path = path
      reload
    end

    # Reload the cached .env values in case the file changed during runtime.
    def reload
      @envs = parse_env_file
    end

    private
      def parse_env_file
        if File.exist?(@path.to_s)
          envs = {}

          File.foreach(@path) do |line|
            line = line.strip

            next if line.empty? || line.start_with?("#")

            # Match KEY=value pattern
            if line =~ /\A([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\z/
              key, value = $1, $2
              envs[key] = interpolate(execute_commands(unquote(value)), envs)
            end
          end

          envs
        else
          {}
        end
      end

      def unquote(value)
        if value.start_with?('"') && value.end_with?('"')
          value[1..-2].gsub('\n', "\n").gsub('\"', '"')
        elsif value.start_with?("'") && value.end_with?("'")
          value[1..-2]
        else
          value
        end
      end

      def execute_commands(value)
        value.gsub(/\$\((.+?)\)/) { `#{$1}`.chomp }
      end

      def interpolate(value, envs)
        value.gsub(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/) { envs[$1] || "" }
      end
  end
end
