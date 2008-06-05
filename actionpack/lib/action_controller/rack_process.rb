require 'action_controller/cgi_ext'
require 'action_controller/session/cookie_store'

module ActionController #:nodoc:
  class RackRequest < AbstractRequest #:nodoc:
    attr_accessor :env, :session_options

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
      @env.key? key
    end

    def query_parameters
      @query_parameters ||= self.class.parse_query_parameters(query_string)
    end

    def request_parameters
      @request_parameters ||= parse_formatted_request_parameters
    end

    def cookies
      return {} unless @env["HTTP_COOKIE"]

      if @env["rack.request.cookie_string"] == @env["HTTP_COOKIE"]
        @env["rack.request.cookie_hash"]
      else
        @env["rack.request.cookie_string"] = @env["HTTP_COOKIE"]
        # According to RFC 2109:
        #   If multiple cookies satisfy the criteria above, they are ordered in
        #   the Cookie header such that those with more specific Path attributes
        #   precede those with less specific.  Ordering with respect to other
        #   attributes (e.g., Domain) is unspecified.
        @env["rack.request.cookie_hash"] =
          parse_query(@env["rack.request.cookie_string"], ';,').inject({}) { |h, (k,v)|
            h[k] = Array === v ? v.first : v
            h
          }
      end
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

      # From Rack::Utils
      def parse_query(qs, d = '&;')
        params = {}
        (qs || '').split(/[#{d}] */n).inject(params) { |h,p|
          k, v = unescape(p).split('=',2)
          if cur = params[k]
            if cur.class == Array
              params[k] << v
            else
              params[k] = [cur, v]
            end
          else
            params[k] = v
          end
        }

        return params
      end

      def unescape(s)
        s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
          [$1.delete('%')].pack('H*')
        }
      end
  end

  class RackResponse < AbstractResponse #:nodoc:
    attr_accessor :status

    def initialize
      @writer = lambda { |x| @body << x }
      @block = nil
      super()
    end

    def out(output = $stdout, &block)
      @block = block
      normalize_headers(@headers)
      if [204, 304].include?(@status.to_i)
        @headers.delete "Content-Type"
        [status.to_i, @headers.to_hash, []]
      else
        [status.to_i, @headers.to_hash, self]
      end
    end
    alias to_a out

    def each(&callback)
      if @body.respond_to?(:call)
        @writer = lambda { |x| callback.call(x) }
        @body.call(self, self)
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

          @status = options.delete('Status') if options['Status']
          @status ||= 200
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

            @output_cookies.each { |c| cookies << c.to_s } if @output_cookies

            headers['Set-Cookie'] = [headers['Set-Cookie'], cookies].compact.join("\n")
          end

          options.each { |k,v| headers[k] = v }
        end

        ""
      end
  end

  class CGIWrapper < ::CGI
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
