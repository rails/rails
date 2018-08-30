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
    # Options are:
    #
    # <tt>:env_name</tt> - The Rails environment, ie "development"
    # <tt>:spec_name</tt> - The specification name. In a standard two-tier
    # database configuration this will default to "primary". In a multiple
    # database three-tier database configuration this corresponds to the name
    # used in the second tier, for example "primary_readonly".
    # <tt>:url</tt> - The database URL.
    # <tt>:config</tt> - The config hash. This is the hash that contains the
    # database adapter, name, and other important information for database
    # connections.
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

      private
        def build_config(original_config, url)
          if /^jdbc:/.match?(url)
            hash = { "url" => url }
          else
            hash = ActiveRecord::ConnectionAdapters::ConnectionSpecification::ConnectionUrlResolver.new(url).to_hash
          end

          if original_config[env_name]
            original_config[env_name].merge(hash)
          else
            original_config.merge(hash)
          end
        end
    end
  end
end
