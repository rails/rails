require 'action_controller/cgi_ext/cgi_ext'
require 'action_controller/cgi_ext/cookie_performance_fix'
require 'action_controller/cgi_ext/raw_post_data_fix'
require 'action_controller/session/drb_store'
require 'action_controller/session/active_record_store'
require 'action_controller/session/mem_cache_store'

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
    attr_accessor :cgi

    DEFAULT_SESSION_OPTIONS =
      { :database_manager => CGI::Session::PStore, :prefix => "ruby_sess.", :session_path => "/" }

    def initialize(cgi, session_options = {})
      @cgi = cgi
      @session_options = session_options
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

    def cookies
      @cgi.cookies.freeze
    end

    def host
      env["HTTP_X_FORWARDED_HOST"] || @cgi.host.to_s.split(":").first
    end
    
    def session
      return @session unless @session.nil?
      begin
        @session = (@session_options == false ? {} : CGI::Session.new(@cgi, session_options_with_string_keys))
        @session["__valid_session"]
        return @session
      rescue ArgumentError => e
        @session.delete if @session
        raise(
          ActionController::SessionRestoreError, 
          "Session contained objects where the class definition wasn't available. " +
          "Remember to require classes for all objects kept in the session. " +
          "The session has been deleted."
        )
      end
    end
    
    def reset_session
      @session.delete
      @session = (@session_options == false ? {} : new_session)
    end

    def method_missing(method_id, *arguments)
      @cgi.send(method_id, *arguments) rescue super
    end

    private
      def new_session
        CGI::Session.new(@cgi, session_options_with_string_keys.merge("new_session" => true))
      end
      
      def session_options_with_string_keys
        DEFAULT_SESSION_OPTIONS.merge(@session_options).inject({}) { |options, pair| options[pair.first.to_s] = pair.last; options }
      end
  end

  class CgiResponse < AbstractResponse #:nodoc:
    def initialize(cgi)
      @cgi = cgi
      super()
    end

    def out
      convert_content_type!(@headers)
      $stdout.binmode if $stdout.respond_to?(:binmode)
      $stdout.sync = false
      print @cgi.header(@headers)

      if @cgi.send(:env_table)['REQUEST_METHOD'] == 'HEAD'
        return
      elsif @body.respond_to?(:call)
        @body.call(self)
      else
        print @body
      end
    end

    private
      def convert_content_type!(headers)
        %w( Content-Type Content-type content-type ).each do |ct|
          if headers[ct]
            headers["type"] = headers[ct]
            headers.delete(ct)
          end
        end
      end
  end
end
