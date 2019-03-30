# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    # A UrlConfig object is created for each database configuration
    # entry that is created from a URL. This can either be a URL string
    # or a hash with a URL in place of the config hash.
    #
    # A URL config:
    #
    #   postgres://localhost/foo
    #
    # Becomes:
    #
    #   #<ActiveRecord::DatabaseConfigurations::UrlConfig:0x00007fdc3238f340
    #     @env_name="default_env", @spec_name="primary",
    #     @config={"adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost"},
    #     @url="postgres://localhost/foo">
    #
    # ==== Options
    #
    # * <tt>:env_name</tt> - The Rails environment, ie "development".
    # * <tt>:spec_name</tt> - The specification name. In a standard two-tier
    #   database configuration this will default to "primary". In a multiple
    #   database three-tier database configuration this corresponds to the name
    #   used in the second tier, for example "primary_readonly".
    # * <tt>:url</tt> - The database URL.
    # * <tt>:config</tt> - The config hash. This is the hash that contains the
    #   database adapter, name, and other important information for database
    #   connections.
    class UrlConfig < DatabaseConfig
      attr_reader :url, :config

      def initialize(env_name, spec_name, url, config = {})
        super(env_name, spec_name)
        @config = build_config(config, url)
        @url = url
      end

      def url_config? # :nodoc:
        true
      end

      # Determines whether a database configuration is for a replica / readonly
      # connection. If the +replica+ key is present in the config, +replica?+ will
      # return +true+.
      def replica?
        config["replica"]
      end

      # The migrations paths for a database configuration. If the
      # +migrations_paths+ key is present in the config, +migrations_paths+
      # will return its value.
      def migrations_paths
        config["migrations_paths"]
      end

      private

        def build_url_hash(url)
          if url.nil? || /^jdbc:/.match?(url)
            { "url" => url }
          else
            ActiveRecord::ConnectionAdapters::ConnectionSpecification::ConnectionUrlResolver.new(url).to_hash
          end
        end

        def build_config(original_config, url)
          hash = build_url_hash(url)

          if original_config[env_name]
            original_config[env_name].merge(hash)
          else
            original_config.merge(hash)
          end
        end
    end
  end
end
