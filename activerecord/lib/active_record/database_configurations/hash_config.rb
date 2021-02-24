# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    # A HashConfig object is created for each database configuration entry that
    # is created from a hash.
    #
    # A hash config:
    #
    #   { "development" => { "database" => "db_name" } }
    #
    # Becomes:
    #
    #   #<ActiveRecord::DatabaseConfigurations::HashConfig:0x00007fd1acbded10
    #     @env_name="development", @name="primary", @config={database: "db_name"}>
    #
    # ==== Options
    #
    # * <tt>:env_name</tt> - The Rails environment, i.e. "development".
    # * <tt>:name</tt> - The db config name. In a standard two-tier
    #   database configuration this will default to "primary". In a multiple
    #   database three-tier database configuration this corresponds to the name
    #   used in the second tier, for example "primary_readonly".
    # * <tt>:config</tt> - The config hash. This is the hash that contains the
    #   database adapter, name, and other important information for database
    #   connections.
    class HashConfig < DatabaseConfig
      attr_reader :configuration_hash
      def initialize(env_name, name, configuration_hash)
        super(env_name, name)
        @configuration_hash = configuration_hash.symbolize_keys.freeze
      end

      def config
        ActiveSupport::Deprecation.warn("DatabaseConfig#config will be removed in 7.0.0 in favor of DatabaseConfigurations#configuration_hash which returns a hash with symbol keys")
        configuration_hash.stringify_keys
      end

      # Determines whether a database configuration is for a replica / readonly
      # connection. If the +replica+ key is present in the config, +replica?+ will
      # return +true+.
      def replica?
        configuration_hash[:replica]
      end

      # The migrations paths for a database configuration. If the
      # +migrations_paths+ key is present in the config, +migrations_paths+
      # will return its value.
      def migrations_paths
        configuration_hash[:migrations_paths]
      end

      # The priority of specific migrations paths.
      def migrations_priority
        configuration_hash[:migrations_priority]&.to_i || 0
      end

      def host
        configuration_hash[:host]
      end

      def database
        configuration_hash[:database]
      end

      def _database=(database) # :nodoc:
        @configuration_hash = configuration_hash.merge(database: database).freeze
      end

      def pool
        (configuration_hash[:pool] || 5).to_i
      end

      def min_threads
        (configuration_hash[:min_threads] || 0).to_i
      end

      def max_threads
        (configuration_hash[:max_threads] || pool).to_i
      end

      def max_queue
        max_threads * 4
      end

      def checkout_timeout
        (configuration_hash[:checkout_timeout] || 5).to_f
      end

      # +reaping_frequency+ is configurable mostly for historical reasons, but it could
      # also be useful if someone wants a very low +idle_timeout+.
      def reaping_frequency
        configuration_hash.fetch(:reaping_frequency, 60)&.to_f
      end

      def idle_timeout
        timeout = configuration_hash.fetch(:idle_timeout, 300).to_f
        timeout if timeout > 0
      end

      def adapter
        configuration_hash[:adapter]
      end

      # The path to the schema cache dump file for a database.
      # If omitted, the filename will be read from ENV or a
      # default will be derived.
      def schema_cache_path
        configuration_hash[:schema_cache_path]
      end
    end
  end
end
