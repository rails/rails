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
    #     @env_name="default_env", @name="primary",
    #     @config={adapter: "postgresql", database: "foo", host: "localhost"},
    #     @url="postgres://localhost/foo">
    #
    # ==== Options
    #
    # * <tt>:env_name</tt> - The Rails environment, i.e. "development".
    # * <tt>:name</tt> - The db config name. In a standard two-tier
    #   database configuration this will default to "primary". In a multiple
    #   database three-tier database configuration this corresponds to the name
    #   used in the second tier, for example "primary_readonly".
    # * <tt>:url</tt> - The database URL.
    # * <tt>:config</tt> - The config hash. This is the hash that contains the
    #   database adapter, name, and other important information for database
    #   connections.
    class UrlConfig < HashConfig
      attr_reader :url

      def initialize(env_name, name, url, configuration_hash = {})
        super(env_name, name, configuration_hash)

        @url = url
        @configuration_hash = @configuration_hash.merge(build_url_hash).freeze
      end

      private
        # Return a Hash that can be merged into the main config that represents
        # the passed in url
        def build_url_hash
          if url.nil? || url.start_with?("jdbc:", "http:", "https:")
            { url: url }
          else
            ConnectionUrlResolver.new(url).to_hash
          end
        end
    end
  end
end
