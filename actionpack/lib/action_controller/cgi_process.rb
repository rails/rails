require 'action_controller/cgi_ext/cgi_ext'
require 'action_controller/cgi_ext/drb_database_manager'

module ActionController #:nodoc:
  class Base
    # Process a request extracted from an CGI object and return a response. Pass false as <tt>session_options</tt> to disable
    # sessions (large performance increase if sessions are not needed). The <tt>session_options</tt> are the same as for CGI::Session:
    #
    # * <tt>:database_manager</tt> - options are CGI::Session::FileStore, CGI::Session::MemoryStore, and CGI::Session::PStore (default)
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

  class CgiRequest < Request #:nodoc:
    attr_accessor :cgi
    attr_reader :session

    DEFAULT_SESSION_OPTIONS =
      { "database_manager" => CGI::Session::PStore, "prefix" => "ruby_sess.", "session_path" => "/" }

    def initialize(cgi, session_options = {})
      @cgi = cgi
      initialize_session(session_options)
      super()
    end

    def query_parameters
      @cgi.query_string ? CGIMethods.parse_query_parameters(@cgi.query_string) : {}
    end

    def request_parameters
      CGIMethods.parse_request_parameters(@cgi.params)
    end
    
    def env
      @cgi.send(:env_table)
    end
    
    def request_uri
      env["REQUEST_URI"]
    end

    def cookies
      @cgi.cookies.freeze
    end

    def method_missing(method_id, *arguments)
      @cgi.send(method_id, *arguments) rescue super
    end
    
    private
      def initialize_session(session_options)
        begin
          @session = (session_options == false ? {} : CGI::Session.new(cgi, DEFAULT_SESSION_OPTIONS.merge(session_options)))
          @session["___valid_session___"]
        rescue ArgumentError => e
          warn "Session contained objects where the class definition wasn't available -- the session has been cleared"
          @session.delete
          retry
        end
      end
  end

  class CgiResponse < Response #:nodoc:
    def initialize(cgi)
      @cgi = cgi
      super()
    end

    def out
      print @cgi.header(@headers)
      print @body
    end
  end
end