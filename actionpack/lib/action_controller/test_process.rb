require File.dirname(__FILE__) + '/assertions/action_pack_assertions'
require File.dirname(__FILE__) + '/assertions/active_record_assertions'

if defined?(RAILS_ROOT)
  # Temporary hack for getting functional tests in Rails running under 1.8.2
  class Object #:nodoc:
    alias_method :require_without_load_path_reloading, :require
    def require(file_name)
      begin
        require_without_load_path_reloading(file_name)
      rescue Object => e
        ADDITIONAL_LOAD_PATHS.reverse.each { |dir| $:.unshift(dir) if File.directory?(dir) }
        require_without_load_path_reloading(file_name)
      end
    end
  end
end


module ActionController #:nodoc:
  class Base
    # Process a test request called with a +TestRequest+ object.
    def self.process_test(request)
      new.process_test(request)
    end
  
    def process_test(request) #:nodoc:
      process(request, TestResponse.new)
    end
  end

  class TestRequest < AbstractRequest #:nodoc:
    attr_writer   :cookies
    attr_accessor :query_parameters, :request_parameters, :session, :env
    attr_accessor :host, :path, :request_uri, :remote_addr

    def initialize(query_parameters = nil, request_parameters = nil, session = nil)
      @query_parameters   = query_parameters || {}
      @request_parameters = request_parameters || {}
      @session            = session || TestSession.new
      
      initialize_containers
      initialize_default_values

      super()
    end

    def reset_session
      @session = {}
    end    

    def cookies
      @cookies.freeze
    end

    def port=(number)
      @env["SERVER_PORT"] = number.to_i
    end

    def action=(action_name)
      @query_parameters.update({ "action" => action_name })
      @parameters = nil
    end
    
    def request_uri=(uri)
      @request_uri = uri
      @path = uri.split("?").first
    end

    private
      def initialize_containers
        @env, @cookies = {}, {}
      end
    
      def initialize_default_values
        @host                    = "test.host"
        @request_uri             = "/"
        @remote_addr, @remote_ip = "127.0.0.1"        
        @env["SERVER_PORT"]      = 80
      end
  end
  
  class TestResponse < AbstractResponse #:nodoc:
    # the class attribute ties a TestResponse to the assertions 
    class << self
      attr_accessor :assertion_target
    end

    # initializer
    def initialize
      TestResponse.assertion_target=self# if TestResponse.assertion_target.nil?
      super()
    end
    
    # the response code of the request
    def response_code
      headers['Status'][0,3].to_i rescue 0
    end
   
    # was the response successful?
    def success?
      response_code == 200
    end

    # was the URL not found?
    def missing?
      response_code == 404
    end

    # were we redirected?
    def redirect?
      (300..399).include?(response_code)
    end
    
    # was there a server-side error?
    def server_error?
      (500..599).include?(response_code)
    end

    # returns the redirection location or nil
    def redirect_url
      redirect? ? headers['location'] : nil
    end
    
    # does the redirect location match this regexp pattern?
    def redirect_url_match?( pattern )
      return false if redirect_url.nil?
      p = Regexp.new(pattern) if pattern.class == String
      p = pattern if pattern.class == Regexp
      return false if p.nil?
      p.match(redirect_url) != nil
    end
   
    # returns the template path of the file which was used to
    # render this response (or nil) 
    def rendered_file(with_controller=false)
      unless template.first_render.nil?
        unless with_controller
          template.first_render
        else
          template.first_render.split('/').last || template.first_render
        end
      end
    end

    # was this template rendered by a file?
    def rendered_with_file?
      !rendered_file.nil?
    end

    # a shortcut to the flash (or an empty hash if no flash.. hey! that rhymes!)
    def flash
      session['flash'] || {}
    end
    
    # do we have a flash? 
    def has_flash?
      !session['flash'].nil?
    end

    # do we have a flash that has contents?
    def has_flash_with_contents?
      !flash.empty?
    end

    # does the specified flash object exist?
    def has_flash_object?(name=nil)
      !flash[name].nil?
    end

    # does the specified object exist in the session?
    def has_session_object?(name=nil)
      !session[name].nil?
    end

    # a shortcut to the template.assigns
    def template_objects
      template.assigns || {}
    end
   
    # does the specified template object exist? 
    def has_template_object?(name=nil)
      !template_objects[name].nil?      
    end
    
    # Returns the response cookies, converted to a Hash of (name => CGI::Cookie) pairs
    # Example:
    # 
    # assert_equal ['AuthorOfNewPage'], r.cookies['author'].value
    def cookies
      headers['cookie'].inject({}) { |hash, cookie| hash[cookie.name] = cookie; hash }
    end

    # Returns binary content (downloadable file), converted to a String
    def binary_content
      raise "Response body is not a Proc: #{body.inspect}" unless body.kind_of?(Proc)
      require 'stringio'

      sio = StringIO.new

      begin 
        $stdout = sio
        body.call
      ensure
        $stdout = STDOUT
      end

      sio.rewind
      sio.read
    end
end

  class TestSession #:nodoc:
    def initialize(attributes = {})
      @attributes = attributes
    end

    def [](key)
      @attributes[key]
    end

    def []=(key, value)
      @attributes[key] = value
    end
    
    def session_id
      ""
    end
    
    def update() end
    def close() end
    def delete() @attributes = {} end
  end
end

module Test
  module Unit
    class TestCase #:nodoc:
      private  
        # execute the request and set/volley the response
        def process(action, parameters = nil, session = nil)
          @request.env['REQUEST_METHOD'] ||= "GET"
          @request.action = action.to_s
          @request.parameters.update(parameters) unless parameters.nil?
          @request.session = ActionController::TestSession.new(session) unless session.nil?
          @controller.process(@request, @response)
        end
    
        # execute the request simulating a specific http method and set/volley the response
        %w( get post put delete head ).each do |method|
          class_eval <<-EOV
            def #{method}(action, parameters = nil, session = nil)
              @request.env['REQUEST_METHOD'] = "#{method.upcase}"
              process(action, parameters, session)
            end
          EOV
        end
    end
  end
end