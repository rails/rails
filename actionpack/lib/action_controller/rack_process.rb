require 'action_controller/cgi_ext'
require 'action_controller/session/cookie_store'

module ActionController #:nodoc:
  class RackRequest < AbstractRequest #:nodoc:
    attr_accessor :env, :session_options
    attr_reader :cgi

    class SessionFixationAttempt < StandardError #:nodoc:
    end

    DEFAULT_SESSION_OPTIONS = {
      :database_manager => CGI::Session::CookieStore, # store data in cookie
      :prefix           => "ruby_sess.",    # prefix session file names
      :session_path     => "/",             # available to all paths in app
      :session_key      => "_session_id",
      :cookie_only      => true
    } unless const_defined?(:DEFAULT_SESSION_OPTIONS)

    def initialize(env, session_options = DEFAULT_SESSION_OPTIONS)
      @session_options = session_options
      @env = env
      @cgi = CGIWrapper.new(self)
      super()
    end

    %w[ AUTH_TYPE GATEWAY_INTERFACE PATH_INFO
        PATH_TRANSLATED QUERY_STRING REMOTE_HOST
        REMOTE_IDENT REMOTE_USER SCRIPT_NAME
        SERVER_NAME SERVER_PROTOCOL

        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_FROM HTTP_HOST
        HTTP_NEGOTIATE HTTP_PRAGMA HTTP_REFERER HTTP_USER_AGENT ].each do |env|
      define_method(env.sub(/^HTTP_/n, '').downcase) do
        @env[env]
      end
    end

    # The request body is an IO input stream. If the RAW_POST_DATA environment
    # variable is already set, wrap it in a StringIO.
    def body
      if raw_post = env['RAW_POST_DATA']
        StringIO.new(raw_post)
      else
        @env['rack.input']
      end
    end

    def key?(key)
      @env.key?(key)
    end

    def query_parameters
      @query_parameters ||= self.class.parse_query_parameters(query_string)
    end

    def request_parameters
      @request_parameters ||= parse_formatted_request_parameters
    end

    def cookies
      return {} unless @env["HTTP_COOKIE"]

      unless @env["rack.request.cookie_string"] == @env["HTTP_COOKIE"]
        @env["rack.request.cookie_string"] = @env["HTTP_COOKIE"]
        @env["rack.request.cookie_hash"] = CGI::Cookie::parse(@env["rack.request.cookie_string"])
      end

      @env["rack.request.cookie_hash"]
    end

    def host_with_port_without_standard_port_handling
      if forwarded = @env["HTTP_X_FORWARDED_HOST"]
        forwarded.split(/,\s?/).last
      elsif http_host = @env['HTTP_HOST']
        http_host
      elsif server_name = @env['SERVER_NAME']
        server_name
      else
        "#{env['SERVER_ADDR']}:#{env['SERVER_PORT']}"
      end
    end

    def host
      host_with_port_without_standard_port_handling.sub(/:\d+$/, '')
    end

    def port
      if host_with_port_without_standard_port_handling =~ /:(\d+)$/
        $1.to_i
      else
        standard_port
      end
    end

    def remote_addr
      @env['REMOTE_ADDR']
    end

    def server_port
      @env['SERVER_PORT'].to_i
    end

    def server_software
      @env['SERVER_SOFTWARE'].split("/").first
    end

    def session
      unless defined?(@session)
        if @session_options == false
          @session = Hash.new
        else
          stale_session_check! do
            if cookie_only? && query_parameters[session_options_with_string_keys['session_key']]
              raise SessionFixationAttempt
            end
            case value = session_options_with_string_keys['new_session']
              when true
                @session = new_session
              when false
                begin
                  @session = CGI::Session.new(@cgi, session_options_with_string_keys)
                # CGI::Session raises ArgumentError if 'new_session' == false
                # and no session cookie or query param is present.
                rescue ArgumentError
                  @session = Hash.new
                end
              when nil
                @session = CGI::Session.new(@cgi, session_options_with_string_keys)
              else
                raise ArgumentError, "Invalid new_session option: #{value}"
            end
            @session['__valid_session']
          end
        end
      end
      @session
    end

    def reset_session
      @session.delete if defined?(@session) && @session.is_a?(CGI::Session)
      @session = new_session
    end

    private
      # Delete an old session if it exists then create a new one.
      def new_session
        if @session_options == false
          Hash.new
        else
          CGI::Session.new(@cgi, session_options_with_string_keys.merge("new_session" => false)).delete rescue nil
          CGI::Session.new(@cgi, session_options_with_string_keys.merge("new_session" => true))
        end
      end

      def cookie_only?
        session_options_with_string_keys['cookie_only']
      end

      def stale_session_check!
        yield
      rescue ArgumentError => argument_error
        if argument_error.message =~ %r{undefined class/module ([\w:]*\w)}
          begin
            # Note that the regexp does not allow $1 to end with a ':'
            $1.constantize
          rescue LoadError, NameError => const_error
            raise ActionController::SessionRestoreError, <<-end_msg
Session contains objects whose class definition isn\'t available.
Remember to require the classes for all objects kept in the session.
(Original exception: #{const_error.message} [#{const_error.class}])
end_msg
          end

          retry
        else
          raise
        end
      end

      def session_options_with_string_keys
        @session_options_with_string_keys ||= DEFAULT_SESSION_OPTIONS.merge(@session_options).stringify_keys
      end
  end

  class RackResponse < AbstractResponse #:nodoc:
    attr_accessor :status

    def initialize(request)
      @request = request
      @writer = lambda { |x| @body << x }
      @block = nil
      super()
    end

    def out(output = $stdout, &block)
      @block = block
      normalize_headers(@headers)
      if [204, 304].include?(@status.to_i)
        @headers.delete "Content-Type"
        [status, @headers.to_hash, []]
      else
        [status, @headers.to_hash, self]
      end
    end
    alias to_a out

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

    private
      def normalize_headers(options = "text/html")
        if options.is_a?(String)
          headers['Content-Type']     = options unless headers['Content-Type']
        else
          headers['Content-Length']   = options.delete('Content-Length').to_s if options['Content-Length']

          headers['Content-Type']     = options.delete('type') || "text/html"
          headers['Content-Type']    += "; charset=" + options.delete('charset') if options['charset']

          headers['Content-Language'] = options.delete('language') if options['language']
          headers['Expires']          = options.delete('expires') if options['expires']

          @status = options.delete('Status') || "200 OK"

          # Convert 'cookie' header to 'Set-Cookie' headers.
          # Because Set-Cookie header can appear more the once in the response body,
          # we store it in a line break separated string that will be translated to
          # multiple Set-Cookie header by the handler.
          if cookie = options.delete('cookie')
            cookies = []

            case cookie
              when Array then cookie.each { |c| cookies << c.to_s }
              when Hash  then cookie.each { |_, c| cookies << c.to_s }
              else            cookies << cookie.to_s
            end

            @request.cgi.output_cookies.each { |c| cookies << c.to_s } if @request.cgi.output_cookies

            headers['Set-Cookie'] = [headers['Set-Cookie'], cookies].flatten.compact
          end

          options.each { |k,v| headers[k] = v }
        end

        ""
      end
  end

  class CGIWrapper < ::CGI
    attr_reader :output_cookies

    def initialize(request, *args)
      @request  = request
      @args     = *args
      @input    = request.body

      super *args
    end

    def params
      @params ||= @request.params
    end

    def cookies
      @request.cookies
    end

    def query_string
      @request.query_string
    end

    # Used to wrap the normal args variable used inside CGI.
    def args
      @args
    end

    # Used to wrap the normal env_table variable used inside CGI.
    def env_table
      @request.env
    end

    # Used to wrap the normal stdinput variable used inside CGI.
    def stdinput
      @input
    end
  end
end
