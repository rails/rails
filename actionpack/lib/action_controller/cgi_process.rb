require 'action_controller/cgi_ext'
require 'action_controller/session/cookie_store'

module ActionController #:nodoc:
  class Base
    # Process a request extracted from an CGI object and return a response. Pass false as <tt>session_options</tt> to disable
    # sessions (large performance increase if sessions are not needed). The <tt>session_options</tt> are the same as for CGI::Session:
    #
    # * <tt>:database_manager</tt> - standard options are CGI::Session::FileStore, CGI::Session::MemoryStore, and CGI::Session::PStore
    #   (default). Additionally, there is CGI::Session::DRbStore and CGI::Session::ActiveRecordStore. Read more about these in
    #   lib/action_controller/session.
    # * <tt>:session_key</tt> - the parameter name used for the session id. Defaults to '_session_id'.
    # * <tt>:session_id</tt> - the session id to use.  If not provided, then it is retrieved from the +session_key+ parameter
    #   of the request, or automatically generated for a new session.
    # * <tt>:new_session</tt> - if true, force creation of a new session.  If not set, a new session is only created if none currently
    #   exists.  If false, a new session is never created, and if none currently exists and the +session_id+ option is not set,
    #   an ArgumentError is raised.
    # * <tt>:session_expires</tt> - the time the current session expires, as a +Time+ object.  If not set, the session will continue
    #   indefinitely.
    # * <tt>:session_domain</tt> -  the hostname domain for which this session is valid. If not set, defaults to the hostname of the
    #   server.
    # * <tt>:session_secure</tt> - if +true+, this session will only work over HTTPS.
    # * <tt>:session_path</tt> - the path for which this session applies.  Defaults to the directory of the CGI script.
    def self.process_cgi(cgi = CGI.new, session_options = {})
      new.process_cgi(cgi, session_options)
    end

    def process_cgi(cgi, session_options = {}) #:nodoc:
      process(CgiRequest.new(cgi, session_options), CgiResponse.new(cgi)).out
    end
  end

  class CgiRequest < AbstractRequest #:nodoc:
    attr_accessor :cgi, :session_options

    DEFAULT_SESSION_OPTIONS = {
      :database_manager => CGI::Session::CookieStore, # store data in cookie
      :prefix           => "ruby_sess.",    # prefix session file names
      :session_path     => "/"              # available to all paths in app
    } unless const_defined?(:DEFAULT_SESSION_OPTIONS)

    def initialize(cgi, session_options = {})
      @cgi = cgi
      @session_options = session_options
      @env = @cgi.send(:env_table)
      super()
    end

    def query_string
      qs = @cgi.query_string
      if !qs.blank?
        qs
      elsif uri = @env['REQUEST_URI']
        uri.split('?', 2).last
      else
        @env['QUERY_STRING'] || ''
      end
    end

    # The request body is an IO input stream. If the RAW_POST_DATA environment
    # variable is already set, wrap it in a StringIO.
    def body
      if raw_post = env['RAW_POST_DATA']
        StringIO.new(raw_post)
      else
        @cgi.stdinput
      end
    end

    def query_parameters
      @query_parameters ||= self.class.parse_query_parameters(query_string)
    end

    def request_parameters
      @request_parameters ||= parse_formatted_request_parameters
    end

    def cookies
      @cgi.cookies.freeze
    end

    def host_with_port
      if forwarded = env["HTTP_X_FORWARDED_HOST"]
        forwarded.split(/,\s?/).last
      elsif http_host = env['HTTP_HOST']
        http_host
      elsif server_name = env['SERVER_NAME']
        server_name
      else
        "#{env['SERVER_ADDR']}:#{env['SERVER_PORT']}"
      end
    end

    def host
      host_with_port[/^[^:]+/]
    end

    def port
      if host_with_port =~ /:(\d+)$/
        $1.to_i
      else
        standard_port
      end
    end

    def session
      unless defined?(@session)
        if @session_options == false
          @session = Hash.new
        else
          stale_session_check! do
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

    def method_missing(method_id, *arguments)
      @cgi.send(method_id, *arguments) rescue super
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

  class CgiResponse < AbstractResponse #:nodoc:
    def initialize(cgi)
      @cgi = cgi
      super()
    end

    def out(output = $stdout)
      output.binmode      if output.respond_to?(:binmode)
      output.sync = false if output.respond_to?(:sync=)

      begin
        output.write(@cgi.header(@headers))

        if @cgi.send(:env_table)['REQUEST_METHOD'] == 'HEAD'
          return
        elsif @body.respond_to?(:call)
          # Flush the output now in case the @body Proc uses
          # #syswrite.
          output.flush if output.respond_to?(:flush)
          @body.call(self, output)
        else
          output.write(@body)
        end

        output.flush if output.respond_to?(:flush)
      rescue Errno::EPIPE, Errno::ECONNRESET
        # lost connection to parent process, ignore output
      end
    end
  end
end
