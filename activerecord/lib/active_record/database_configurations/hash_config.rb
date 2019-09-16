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
    #     @env_name="development", @spec_name="primary", @config={database: "db_name"}>
    #
    # ==== Options
    #
    # * <tt>:env_name</tt> - The Rails environment, i.e. "development".
    # * <tt>:spec_name</tt> - The specification name. In a standard two-tier
    #   database configuration this will default to "primary". In a multiple
    #   database three-tier database configuration this corresponds to the name
    #   used in the second tier, for example "primary_readonly".
    # * <tt>:config</tt> - The config hash. This is the hash that contains the
    #   database adapter, name, and other important information for database
    #   connections.
    class HashConfig < DatabaseConfig
      def initialize(env_name, spec_name, config)
        super(env_name, spec_name)
        @config = config.symbolize_keys

        resolve_url_key
      end

      def configuration_hash
        @config
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

      private
        def resolve_url_key
          if configuration_hash[:url] && !configuration_hash[:url].match?(/^jdbc:/)
            connection_hash = ConnectionUrlResolver.new(configuration_hash[:url]).to_hash
            configuration_hash.merge!(connection_hash)
          end
        end
    end
  end
end
