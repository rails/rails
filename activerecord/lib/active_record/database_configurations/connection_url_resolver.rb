# frozen_string_literal: true

require "uri"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/hash/reverse_merge"

module ActiveRecord
  class DatabaseConfigurations
    # Expands a connection string into a hash.
    class ConnectionUrlResolver # :nodoc:
      # == Example
      #
      #   url = "postgresql://foo:bar@localhost:9000/foo_test?pool=5&timeout=3000"
      #   ConnectionUrlResolver.new(url).to_hash
      #   # => {
      #     adapter:  "postgresql",
      #     host:     "localhost",
      #     port:     9000,
      #     database: "foo_test",
      #     username: "foo",
      #     password: "bar",
      #     pool:     "5",
      #     timeout:  "3000"
      #   }
      def initialize(url)
        raise "Database URL cannot be empty" if url.blank?
        @uri     = uri_parser.parse(url)
        @adapter = resolved_adapter

        if @uri.opaque
          @uri.opaque, @query = @uri.opaque.split("?", 2)
        else
          @query = @uri.query
        end
      end

      # Converts the given URL to a full connection hash.
      def to_hash
        config = raw_config.compact_blank
        config.map { |key, value| config[key] = uri_parser.unescape(value) if value.is_a? String }
        config
      end

      private
        attr_reader :uri

        def uri_parser
          @uri_parser ||= URI::RFC2396_Parser.new
        end

        # Converts the query parameters of the URI into a hash.
        #
        #   "localhost?pool=5&reaping_frequency=2"
        #   # => { pool: "5", reaping_frequency: "2" }
        #
        # returns empty hash if no query present.
        #
        #   "localhost"
        #   # => {}
        def query_hash
          Hash[(@query || "").split("&").map { |pair| pair.split("=", 2) }].symbolize_keys
        end

        def raw_config
          if uri.opaque
            query_hash.merge(
              adapter: @adapter,
              database: uri.opaque
            )
          else
            query_hash.reverse_merge(
              adapter: @adapter,
              username: uri.user,
              password: uri.password,
              port: uri.port,
              database: database_from_path,
              host: uri.hostname
            )
          end
        end

        def resolved_adapter
          adapter = uri.scheme && @uri.scheme.tr("-", "_")
          if adapter && ActiveRecord.protocol_adapters[adapter]
            adapter = ActiveRecord.protocol_adapters[adapter]
          end
          adapter
        end

        # Returns name of the database.
        def database_from_path
          if @adapter == "sqlite3"
            # 'sqlite3:/foo' is absolute, because that makes sense. The
            # corresponding relative version, 'sqlite3:foo', is handled
            # elsewhere, as an "opaque".

            uri.path
          else
            # Only SQLite uses a filename as the "database" name; for
            # anything else, a leading slash would be silly.

            uri.path.delete_prefix("/")
          end
        end
    end
  end
end
