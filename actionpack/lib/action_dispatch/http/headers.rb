module ActionDispatch
  module Http
    class Headers
      NON_PREFIX_VARIABLES = %w(
        CONTENT_TYPE CONTENT_LENGTH
        HTTPS AUTH_TYPE GATEWAY_INTERFACE
        PATH_INFO PATH_TRANSLATED QUERY_STRING
        REMOTE_ADDR REMOTE_HOST REMOTE_IDENT REMOTE_USER
        REQUEST_METHOD SCRIPT_NAME
        SERVER_NAME SERVER_PORT SERVER_PROTOCOL SERVER_SOFTWARE
      )
      HEADER_REGEXP = /\A[A-Za-z-]+\z/

      include Enumerable

      def initialize(env = {})
        @headers = env
      end

      def [](header_name)
        @headers[env_name(header_name)]
      end

      def []=(k,v); @headers[k] = v; end
      def key?(k); @headers.key? k; end
      alias :include? :key?

      def fetch(header_name, *args, &block)
        @headers.fetch env_name(header_name), *args, &block
      end

      def each(&block)
        @headers.each(&block)
      end

      private

      # Converts a HTTP header name to an environment variable name if it is
      # not contained within the headers hash.
      def env_name(header_name)
        @headers.include?(header_name) ? header_name : cgi_name(header_name)
      end

      def cgi_name(k)
        k = k.upcase.gsub(/-/, '_')
        k = "HTTP_#{k.upcase.gsub(/-/, '_')}" unless NON_PREFIX_VARIABLES.include?(k)
        k
      end
    end
  end
end
