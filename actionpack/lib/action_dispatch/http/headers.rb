# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module Http
    # # Action Dispatch HTTP Headers
    #
    # Provides access to the request's HTTP headers from the environment.
    #
    #     env     = { "CONTENT_TYPE" => "text/plain", "HTTP_USER_AGENT" => "curl/7.43.0" }
    #     headers = ActionDispatch::Http::Headers.from_hash(env)
    #     headers["Content-Type"] # => "text/plain"
    #     headers["User-Agent"] # => "curl/7.43.0"
    #
    # Also note that when headers are mapped to CGI-like variables by the Rack
    # server, both dashes and underscores are converted to underscores. This
    # ambiguity cannot be resolved at this stage anymore. Both underscores and
    # dashes have to be interpreted as if they were originally sent as dashes.
    #
    #     # GET / HTTP/1.1
    #     # ...
    #     # User-Agent: curl/7.43.0
    #     # X_Custom_Header: token
    #
    #     headers["X_Custom_Header"] # => nil
    #     headers["X-Custom-Header"] # => "token"
    class Headers
      CGI_VARIABLES = Set.new(%W[
        AUTH_TYPE
        CONTENT_LENGTH
        CONTENT_TYPE
        GATEWAY_INTERFACE
        HTTPS
        PATH_INFO
        PATH_TRANSLATED
        QUERY_STRING
        REMOTE_ADDR
        REMOTE_HOST
        REMOTE_IDENT
        REMOTE_USER
        REQUEST_METHOD
        SCRIPT_NAME
        SERVER_NAME
        SERVER_PORT
        SERVER_PROTOCOL
        SERVER_SOFTWARE
      ]).freeze

      HTTP_HEADER = /\A[A-Za-z0-9-]+\z/

      include Enumerable

      def self.from_hash(hash)
        new ActionDispatch::Request.new hash
      end

      def initialize(request) # :nodoc:
        @req = request
      end

      # Returns the value for the given key mapped to @env.
      def [](key)
        @req.get_header env_name(key)
      end

      # Sets the given value for the key mapped to @env.
      def []=(key, value)
        @req.set_header env_name(key), value
      end

      # Add a value to a multivalued header like `Vary` or `Accept-Encoding`.
      def add(key, value)
        @req.add_header env_name(key), value
      end

      def key?(key)
        @req.has_header? env_name(key)
      end
      alias :include? :key?

      DEFAULT = Object.new # :nodoc:

      # Returns the value for the given key mapped to @env.
      #
      # If the key is not found and an optional code block is not provided, raises a
      # `KeyError` exception.
      #
      # If the code block is provided, then it will be run and its result returned.
      def fetch(key, default = DEFAULT)
        @req.fetch_header(env_name(key)) do
          return default unless default == DEFAULT
          return yield if block_given?
          raise KeyError, key
        end
      end

      def each(&block)
        @req.each_header(&block)
      end

      # Returns a new Http::Headers instance containing the contents of
      # `headers_or_env` and the original instance.
      def merge(headers_or_env)
        headers = @req.dup.headers
        headers.merge!(headers_or_env)
        headers
      end

      # Adds the contents of `headers_or_env` to original instance entries; duplicate
      # keys are overwritten with the values from `headers_or_env`.
      def merge!(headers_or_env)
        headers_or_env.each do |key, value|
          @req.set_header env_name(key), value
        end
      end

      def env; @req.env.dup; end

      private
        # Converts an HTTP header name to an environment variable name if it is not
        # contained within the headers hash.
        def env_name(key)
          key = key.to_s
          if HTTP_HEADER.match?(key)
            key = key.upcase
            key.tr!("-", "_")
            key.prepend("HTTP_") unless CGI_VARIABLES.include?(key)
          end
          key
        end
    end
  end
end
