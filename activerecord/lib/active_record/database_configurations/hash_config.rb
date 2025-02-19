# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  class DatabaseConfigurations
    # # Active Record Database Hash Config
    #
    # A `HashConfig` object is created for each database configuration entry that is
    # created from a hash.
    #
    # A hash config:
    #
    #     { "development" => { "database" => "db_name" } }
    #
    # Becomes:
    #
    #     #<ActiveRecord::DatabaseConfigurations::HashConfig:0x00007fd1acbded10
    #       @env_name="development", @name="primary", @config={database: "db_name"}>
    #
    # See ActiveRecord::DatabaseConfigurations for more info.
    class HashConfig < DatabaseConfig
      attr_reader :configuration_hash

      # Initialize a new `HashConfig` object
      #
      # #### Parameters
      #
      # *   `env_name` - The Rails environment, i.e. "development".
      # *   `name` - The db config name. In a standard two-tier database configuration
      #     this will default to "primary". In a multiple database three-tier database
      #     configuration this corresponds to the name used in the second tier, for
      #     example "primary_readonly".
      # *   `configuration_hash` - The config hash. This is the hash that contains the
      #     database adapter, name, and other important information for database
      #     connections.
      #
      def initialize(env_name, name, configuration_hash)
        super(env_name, name)
        @configuration_hash = configuration_hash.symbolize_keys.freeze
        ActiveRecord.deprecator.warn(<<~MSG) if @configuration_hash[:pool]
          The pool option is deprecated and will be removed in Rails 8.2. Use max_connections instead.
        MSG
      end

      # Determines whether a database configuration is for a replica / readonly
      # connection. If the `replica` key is present in the config, `replica?` will
      # return `true`.
      def replica?
        configuration_hash[:replica]
      end

      # The migrations paths for a database configuration. If the `migrations_paths`
      # key is present in the config, `migrations_paths` will return its value.
      def migrations_paths
        configuration_hash[:migrations_paths]
      end

      def host
        configuration_hash[:host]
      end

      def socket # :nodoc:
        configuration_hash[:socket]
      end

      def database
        configuration_hash[:database]
      end

      def _database=(database) # :nodoc:
        @configuration_hash = configuration_hash.merge(database: database).freeze
      end

      def max_connections
        (configuration_hash[:max_connections] || configuration_hash[:pool] || 5).to_i
      end

      def min_connections
        (configuration_hash[:min_connections] || 0).to_i
      end

      alias :pool :max_connections
      deprecate pool: :max_connections, deprecator: ActiveRecord.deprecator

      def min_threads
        (configuration_hash[:min_threads] || 0).to_i
      end

      def max_threads
        (configuration_hash[:max_threads] || max_connections).to_i
      end

      def max_age
        v = configuration_hash[:max_age]&.to_i
        if v && v > 0
          v
        else
          Float::INFINITY
        end
      end

      def query_cache
        configuration_hash[:query_cache]
      end

      def max_queue
        max_threads * 4
      end

      def checkout_timeout
        (configuration_hash[:checkout_timeout] || 5).to_f
      end

      def reaping_frequency # :nodoc:
        configuration_hash.fetch(:reaping_frequency, default_reaping_frequency)&.to_f
      end

      def idle_timeout
        timeout = configuration_hash.fetch(:idle_timeout, 300).to_f
        timeout if timeout > 0
      end

      def keepalive
        keepalive = (configuration_hash[:keepalive] || 600).to_f
        keepalive if keepalive > 0
      end

      def adapter
        configuration_hash[:adapter]&.to_s
      end

      # The path to the schema cache dump file for a database. If omitted, the
      # filename will be read from ENV or a default will be derived.
      def schema_cache_path
        configuration_hash[:schema_cache_path]
      end

      def default_schema_cache_path(db_dir = "db")
        if primary?
          File.join(db_dir, "schema_cache.yml")
        else
          File.join(db_dir, "#{name}_schema_cache.yml")
        end
      end

      def lazy_schema_cache_path
        schema_cache_path || default_schema_cache_path
      end

      def primary? # :nodoc:
        Base.configurations.primary?(name)
      end

      # Determines whether the db:prepare task should seed the database from db/seeds.rb.
      #
      # If the `seeds` key is present in the config, `seeds?` will return its value.  Otherwise, it
      # will return `true` for the primary database and `false` for all other configs.
      def seeds?
        configuration_hash.fetch(:seeds, primary?)
      end

      # Determines whether to dump the schema/structure files and the filename that
      # should be used.
      #
      # If `configuration_hash[:schema_dump]` is set to `false` or `nil` the schema
      # will not be dumped.
      #
      # If the config option is set that will be used. Otherwise Rails will generate
      # the filename from the database config name.
      def schema_dump(format = schema_format)
        if configuration_hash.key?(:schema_dump)
          if config = configuration_hash[:schema_dump]
            config
          end
        elsif primary?
          schema_file_type(format)
        else
          "#{name}_#{schema_file_type(format)}"
        end
      end

      def schema_format # :nodoc:
        format = configuration_hash.fetch(:schema_format, ActiveRecord.schema_format).to_sym
        raise "Invalid schema format" unless [:ruby, :sql].include?(format)
        format
      end

      def database_tasks? # :nodoc:
        !replica? && !!configuration_hash.fetch(:database_tasks, true)
      end

      def use_metadata_table? # :nodoc:
        configuration_hash.fetch(:use_metadata_table, true)
      end

      private
        def schema_file_type(format)
          case format.to_sym
          when :ruby
            "schema.rb"
          when :sql
            "structure.sql"
          end
        end

        def default_reaping_frequency
          # Reap every 20 seconds by default, but run more often as necessary to
          # meet other configured timeouts.
          [20, idle_timeout, max_age, keepalive].compact.min
        end
    end
  end
end
