require 'action_controller/cgi_ext/cgi_ext'
require 'action_controller/cgi_ext/cookie_performance_fix'
require 'action_controller/cgi_ext/raw_post_data_fix'
require 'action_controller/cgi_ext/session_performance_fix'
require 'action_controller/cgi_ext/pstore_performance_fix'

module ActionController #:nodoc:
  class Base
    # Process a request extracted from an CGI object and return a response. Pass false as <tt>session_options</tt> to disable
    # sessions (large performance increase if sessions are not needed). The <tt>session_options</tt> are the same as for CGI::Session:
    #
    # * <tt>:database_manager</tt> - standard options are CGI::Session::FileStore, CGI::Session::MemoryStore, and CGI::Session::PStore
    #   (default). Additionally, there is CGI::Session::DRbStore and CGI::Session::ActiveRecordStore. Read more about these in
    #   lib/action_controller/session.
    # * <tt>:session_key</tt> - the parameter name used for the session id. Defaults to '_session_id'.
    # * <tt>:session_id</tt> - the session id to use.  If not provided, then it is retrieved from the +session_key+ cookie, or 
    #   automatically generated for a new session.
    # * <tt>:new_session</tt> - if true, force creation of a new session.  If not set, a new session is only created if none currently
    #   exists.  If false, a new session is never created, and if none currently exists and the +session_id+ option is not set,
    #   an ArgumentError is raised.
    # * <tt>:session_expires</tt> - the time the current session expires, as a +Time+ object.  If not set, the session will continue
    #   indefinitely.
    # * <tt>:session_domain</tt> -  the hostname domain for which this session is valid. If not set, defaults to the hostname of the
    #   server.
    # * <tt>:session_secure</tt> - if +true+, this session will only work over HTTPS.
    # * <tt>:session_path</tt> - the path for which this session applies.  Defaults to the directory of the CGI script.
    # * <tt>:cookie_only</tt> - if +true+ (the default), session IDs will only be accepted from cookies and not from
    #   the query string or POST parameters. This protects against session fixation attacks.
    def self.process_cgi(cgi = CGI.new, session_options = {})
      new.process_cgi(cgi, session_options)
    end

    def process_cgi(cgi, session_options = {}) #:nodoc:
      process(CgiRequest.new(cgi, session_options), CgiResponse.new(cgi)).out
    end
  end

  class CgiRequest < AbstractRequest #:nodoc:
    attr_accessor :cgi, :session_options, :cookie_only
    class SessionFixationAttempt < StandardError; end #:nodoc:

    DEFAULT_SESSION_OPTIONS = {
      :database_manager => CGI::Session::PStore,
      :prefix           => "ruby_sess.",
      :session_path     => "/",
      :cookie_only      => true
    } unless const_defined?(:DEFAULT_SESSION_OPTIONS)

    def initialize(cgi, session_options = {})
      @cgi = cgi
      @session_options = session_options
      @env = @cgi.send(:env_table)
      @cookie_only = session_options.delete :cookie_only
      super()
    end

    def query_string
      if (qs = @cgi.query_string) && !qs.empty?
        qs
      elsif uri = @env['REQUEST_URI']
        parts = uri.split('?')
        parts.shift
        parts.join('?')
      else
        @env['QUERY_STRING'] || ''
      end
    end

    def query_parameters
      @query_parameters ||=
        (qs = self.query_string).empty? ? {} : CGIMethods.parse_query_parameters(qs)
    end

    def request_parameters
      @request_parameters ||=
        if ActionController::Base.param_parsers.has_key?(content_type)
          CGIMethods.parse_formatted_request_parameters(content_type, @env['RAW_POST_DATA'])
        else
          CGIMethods.parse_request_parameters(@cgi.params)
        end
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
            if @cookie_only && request_parameters[session_options_with_string_keys['session_key']]
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
        if argument_error.message =~ %r{undefined class/module ([\w:]+)}
          begin
            Module.const_missing($1)
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
      convert_content_type!
      set_content_length!

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

    private
      def convert_content_type!
        if content_type = @headers.delete("Content-Type")
          @headers["type"] = content_type
        end
        if content_type = @headers.delete("Content-type")
          @headers["type"] = content_type
        end
        if content_type = @headers.delete("content-type")
          @headers["type"] = content_type
        end
      end
      
      # Don't set the Content-Length for block-based bodies as that would mean reading it all into memory. Not nice
      # for, say, a 2GB streaming file.
      def set_content_length!
        @headers["Content-Length"] = @body.size unless @body.respond_to?(:call)
      end
  end
end
