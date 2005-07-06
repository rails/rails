require 'action_controller/cgi_ext/cgi_ext'
require 'action_controller/cgi_ext/cookie_performance_fix'
require 'action_controller/cgi_ext/raw_post_data_fix'
require 'action_controller/session/drb_store'
require 'action_controller/session/mem_cache_store'
if Object.const_defined?(:ActiveRecord)
  require 'action_controller/session/active_record_store'
end

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

    DEFAULT_SESSION_OPTIONS = {
      :database_manager => CGI::Session::PStore,
      :prefix => "ruby_sess.",
      :session_path => "/"
    } unless const_defined?(:DEFAULT_SESSION_OPTIONS)

    def initialize(cgi, session_options = {})
      @cgi = cgi
      @session_options = session_options
      super()
    end

    def query_string
      return @cgi.query_string unless @cgi.query_string.nil? || @cgi.query_string.empty?
      unless env['REQUEST_URI'].nil?
        parts = env['REQUEST_URI'].split('?')
      else
        return env['QUERY_STRING'] || ''
      end      
      parts.shift
      return parts.join('?')
    end

    def query_parameters
      qs = self.query_string
      qs.empty? ? {} : CGIMethods.parse_query_parameters(query_string)
    end

    def request_parameters
      if formatted_post?
        CGIMethods.parse_formatted_request_parameters(post_format, env['RAW_POST_DATA'])
      else
        CGIMethods.parse_request_parameters(@cgi.params)
      end
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
        if e.message =~ %r{undefined class/module (\w+)}
          begin
            Module.const_missing($1)
          rescue LoadError, NameError => e
            raise(
              ActionController::SessionRestoreError, 
              "Session contained objects where the class definition wasn't available. " +
              "Remember to require classes for all objects kept in the session. " +
              "(Original exception: #{e.message} [#{e.class}])"
            )
          end
        
          retry
        else
          raise
        end
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

    def out(output = $stdout)
      convert_content_type!(@headers)
      output.binmode      if output.respond_to?(:binmode)
      output.sync = false if output.respond_to?(:sync=)
      
      begin
        output.write(@cgi.header(@headers))

        if @cgi.send(:env_table)['REQUEST_METHOD'] == 'HEAD'
          return
        elsif @body.respond_to?(:call)
          @body.call(self)
        else
          output.write(@body)
        end

        output.flush if output.respond_to?(:flush)
      rescue Errno::EPIPE => e
        # lost connection to the FCGI process -- ignore the output, then
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
