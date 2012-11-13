module ActionDispatch
  module Http
    class Headers
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
        "HTTP_#{k.upcase.gsub(/-/, '_')}"
      end
    end
  end
end
