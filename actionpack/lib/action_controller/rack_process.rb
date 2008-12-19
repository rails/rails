require 'action_controller/cgi_ext'

module ActionController #:nodoc:
  class RackRequest < AbstractRequest #:nodoc:
    attr_accessor :session_options

    class SessionFixationAttempt < StandardError #:nodoc:
    end

    def initialize(env)
      @env = env
      super()
    end

    %w[ AUTH_TYPE GATEWAY_INTERFACE PATH_INFO
        PATH_TRANSLATED REMOTE_HOST
        REMOTE_IDENT REMOTE_USER SCRIPT_NAME
        SERVER_NAME SERVER_PROTOCOL

        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_FROM
        HTTP_NEGOTIATE HTTP_PRAGMA HTTP_REFERER HTTP_USER_AGENT ].each do |env|
      define_method(env.sub(/^HTTP_/n, '').downcase) do
        @env[env]
      end
    end

    def query_string
      qs = super
      if !qs.blank?
        qs
      else
        @env['QUERY_STRING']
      end
    end

    def body_stream #:nodoc:
      @env['rack.input']
    end

    def key?(key)
      @env.key?(key)
    end

    def cookies
      Rack::Request.new(@env).cookies
    end

    def server_port
      @env['SERVER_PORT'].to_i
    end

    def server_software
      @env['SERVER_SOFTWARE'].split("/").first
    end

    def session_options
      @env['rack.session.options'] ||= {}
    end

    def session_options=(options)
      @env['rack.session.options'] = options
    end

    def session
      @env['rack.session'] ||= {}
    end

    def reset_session
      @env['rack.session'] = {}
    end
  end

  class RackResponse < AbstractResponse #:nodoc:
    def initialize
      @writer = lambda { |x| @body << x }
      @block = nil
      super()
    end

    # Retrieve status from instance variable if has already been delete
    def status
      @status || super
    end

    def to_a(&block)
      @block = block
      @status = headers.delete("Status")
      if [204, 304].include?(status.to_i)
        headers.delete("Content-Type")
        [status, headers.to_hash, []]
      else
        [status, headers.to_hash, self]
      end
    end

    def each(&callback)
      if @body.respond_to?(:call)
        @writer = lambda { |x| callback.call(x) }
        @body.call(self, self)
      elsif @body.is_a?(String)
        @body.each_line(&callback)
      else
        @body.each(&callback)
      end

      @writer = callback
      @block.call(self) if @block
    end

    def write(str)
      @writer.call str.to_s
      str
    end

    def close
      @body.close if @body.respond_to?(:close)
    end

    def empty?
      @block == nil && @body.empty?
    end

    def prepare!
      super

      convert_language!
      convert_expires!
      set_status!
      set_cookies!
    end

    private
      def convert_language!
        headers["Content-Language"] = headers.delete("language") if headers["language"]
      end

      def convert_expires!
        headers["Expires"] = headers.delete("") if headers["expires"]
      end

      def convert_content_type!
        super
        headers['Content-Type'] = headers.delete('type') || "text/html"
        headers['Content-Type'] += "; charset=" + headers.delete('charset') if headers['charset']
      end

      def set_content_length!
        super
        headers["Content-Length"] = headers["Content-Length"].to_s if headers["Content-Length"]
      end

      def set_status!
        self.status ||= "200 OK"
      end

      def set_cookies!
        # Convert 'cookie' header to 'Set-Cookie' headers.
        # Because Set-Cookie header can appear more the once in the response body,
        # we store it in a line break separated string that will be translated to
        # multiple Set-Cookie header by the handler.
        if cookie = headers.delete('cookie')
          cookies = []

          case cookie
            when Array then cookie.each { |c| cookies << c.to_s }
            when Hash  then cookie.each { |_, c| cookies << c.to_s }
            else            cookies << cookie.to_s
          end

          headers['Set-Cookie'] = [headers['Set-Cookie'], cookies].flatten.compact
        end
      end
  end
end
