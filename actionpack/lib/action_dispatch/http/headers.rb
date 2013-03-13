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
        @env = env
      end

      def [](key)
        @env[env_name(key)]
      end

      def []=(key, value)
        @env[env_name(key)] = value
      end

      def key?(key); @env.key? key; end
      alias :include? :key?

      def fetch(key, *args, &block)
        @env.fetch env_name(key), *args, &block
      end

      def each(&block)
        @env.each(&block)
      end

      private
      def env_name(key)
        if key =~ HEADER_REGEXP
          cgi_name(key)
        else
          key
        end
      end

      def cgi_name(key)
        key = key.upcase.gsub(/-/, '_')
        key = "HTTP_#{key}" unless NON_PREFIX_VARIABLES.include?(key)
        key
      end
    end
  end
end
