require 'action_controller/assertions'

module ActionController #:nodoc:
  class Base
    # Process a test request called with a +TestRequest+ object.
    def self.process_test(request)
      new.process_test(request)
    end

    def process_test(request) #:nodoc:
      process(request, TestResponse.new)
    end

    def process_with_test(*args)
      returning process_without_test(*args) do
        add_variables_to_assigns
      end
    end

    alias_method_chain :process, :test
  end

  class TestRequest < AbstractRequest #:nodoc:
    attr_accessor :cookies, :session_options
    attr_accessor :query_parameters, :request_parameters, :path, :session, :env
    attr_accessor :host, :user_agent

    def initialize(query_parameters = nil, request_parameters = nil, session = nil)
      @query_parameters   = query_parameters || {}
      @request_parameters = request_parameters || {}
      @session            = session || TestSession.new

      initialize_containers
      initialize_default_values

      super()
    end

    def reset_session
      @session = TestSession.new
    end

    # Wraps raw_post in a StringIO.
    def body
      StringIO.new(raw_post)
    end

    # Either the RAW_POST_DATA environment variable or the URL-encoded request
    # parameters.
    def raw_post
      env['RAW_POST_DATA'] ||= url_encoded_request_parameters
    end

    def port=(number)
      @env["SERVER_PORT"] = number.to_i
      @port_as_int = nil
    end

    def action=(action_name)
      @query_parameters.update({ "action" => action_name })
      @parameters = nil
    end

    # Used to check AbstractRequest's request_uri functionality.
    # Disables the use of @path and @request_uri so superclass can handle those.
    def set_REQUEST_URI(value)
      @env["REQUEST_URI"] = value
      @request_uri = nil
      @path = nil
    end

    def request_uri=(uri)
      @request_uri = uri
      @path = uri.split("?").first
    end

    def accept=(mime_types)
      @env["HTTP_ACCEPT"] = Array(mime_types).collect { |mime_types| mime_types.to_s }.join(",")
    end

    def remote_addr=(addr)
      @env['REMOTE_ADDR'] = addr
    end

    def remote_addr
      @env['REMOTE_ADDR']
    end

    def request_uri
      @request_uri || super
    end

    def path
      @path || super
    end

    def assign_parameters(controller_path, action, parameters)
      parameters = parameters.symbolize_keys.merge(:controller => controller_path, :action => action)
      extra_keys = ActionController::Routing::Routes.extra_keys(parameters)
      non_path_parameters = get? ? query_parameters : request_parameters
      parameters.each do |key, value|
        if value.is_a? Fixnum
          value = value.to_s
        elsif value.is_a? Array
          value = ActionController::Routing::PathSegment::Result.new(value)
        end

        if extra_keys.include?(key.to_sym)
          non_path_parameters[key] = value
        else
          path_parameters[key.to_s] = value
        end
      end
      @parameters = nil # reset TestRequest#parameters to use the new path_parameters
    end                        
    
    def recycle!
      self.request_parameters = {}
      self.query_parameters   = {}
      self.path_parameters    = {}
      @request_method, @accepts, @content_type = nil, nil, nil
    end    

    def referer
      @env["HTTP_REFERER"]
    end

    private
      def initialize_containers
        @env, @cookies = {}, {}
      end

      def initialize_default_values
        @host                    = "test.host"
        @request_uri             = "/"
        @user_agent              = "Rails Testing"
        self.remote_addr         = "0.0.0.0"        
        @env["SERVER_PORT"]      = 80
        @env['REQUEST_METHOD']   = "GET"
      end

      def url_encoded_request_parameters
        params = self.request_parameters.dup

        %w(controller action only_path).each do |k|
          params.delete(k)
          params.delete(k.to_sym)
        end

        params.to_query
      end
  end

  # A refactoring of TestResponse to allow the same behavior to be applied
  # to the "real" CgiResponse class in integration tests.
  module TestResponseBehavior #:nodoc:
    # the response code of the request
    def response_code
      headers['Status'][0,3].to_i rescue 0
    end
    
    # returns a String to ensure compatibility with Net::HTTPResponse
    def code
      headers['Status'].to_s.split(' ')[0]
    end

    def message
      headers['Status'].to_s.split(' ',2)[1]
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
    def error?
      (500..599).include?(response_code)
    end

    alias_method :server_error?, :error?

    # returns the redirection location or nil
    def redirect_url
      headers['Location']
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
      !session['flash'].empty?
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
      body.call(self, sio)

      sio.rewind
      sio.read
    end
  end

  class TestResponse < AbstractResponse #:nodoc:
    include TestResponseBehavior
  end

  class TestSession #:nodoc:
    attr_accessor :session_id

    def initialize(attributes = nil)
      @session_id = ''
      @attributes = attributes
      @saved_attributes = nil
    end

    def data
      @attributes ||= @saved_attributes || {}
    end

    def [](key)
      data[key]
    end

    def []=(key, value)
      data[key] = value
    end

    def update
      @saved_attributes = @attributes
    end

    def delete
      @attributes = nil
    end

    def close
      update
      delete
    end
  end

  # Essentially generates a modified Tempfile object similar to the object
  # you'd get from the standard library CGI module in a multipart
  # request. This means you can use an ActionController::TestUploadedFile
  # object in the params of a test request in order to simulate
  # a file upload.
  #
  # Usage example, within a functional test:
  #   post :change_avatar, :avatar => ActionController::TestUploadedFile.new(Test::Unit::TestCase.fixture_path + '/files/spongebob.png', 'image/png')
  # 
  # Pass a true third parameter to ensure the uploaded file is opened in binary mode (only required for Windows):
  #   post :change_avatar, :avatar => ActionController::TestUploadedFile.new(Test::Unit::TestCase.fixture_path + '/files/spongebob.png', 'image/png', :binary)
  require 'tempfile'
  class TestUploadedFile
    # The filename, *not* including the path, of the "uploaded" file
    attr_reader :original_filename

    # The content type of the "uploaded" file
    attr_reader :content_type

    def initialize(path, content_type = Mime::TEXT, binary = false)
      raise "#{path} file does not exist" unless File.exist?(path)
      @content_type = content_type
      @original_filename = path.sub(/^.*#{File::SEPARATOR}([^#{File::SEPARATOR}]+)$/) { $1 }
      @tempfile = Tempfile.new(@original_filename)
      @tempfile.binmode if binary
      FileUtils.copy_file(path, @tempfile.path)
    end

    def path #:nodoc:
      @tempfile.path
    end

    alias local_path path

    def method_missing(method_name, *args, &block) #:nodoc:
      @tempfile.send!(method_name, *args, &block)
    end
  end

  module TestProcess
    def self.included(base)
      # execute the request simulating a specific http method and set/volley the response
      %w( get post put delete head ).each do |method|
        base.class_eval <<-EOV, __FILE__, __LINE__
          def #{method}(action, parameters = nil, session = nil, flash = nil)
            @request.env['REQUEST_METHOD'] = "#{method.upcase}" if defined?(@request)
            process(action, parameters, session, flash)
          end
        EOV
      end
    end

    # execute the request and set/volley the response
    def process(action, parameters = nil, session = nil, flash = nil)
      # Sanity check for required instance variables so we can give an
      # understandable error message.
      %w(@controller @request @response).each do |iv_name|
        if !(instance_variables.include?(iv_name) || instance_variables.include?(iv_name.to_sym)) || instance_variable_get(iv_name).nil?
          raise "#{iv_name} is nil: make sure you set it in your test's setup method."
        end
      end

      @request.recycle!

      @html_document = nil
      @request.env['REQUEST_METHOD'] ||= "GET"
      @request.action = action.to_s

      parameters ||= {}
      @request.assign_parameters(@controller.class.controller_path, action.to_s, parameters)

      @request.session = ActionController::TestSession.new(session) unless session.nil?
      @request.session["flash"] = ActionController::Flash::FlashHash.new.update(flash) if flash
      build_request_uri(action, parameters)
      @controller.process(@request, @response)
    end

    def xml_http_request(request_method, action, parameters = nil, session = nil, flash = nil)
      @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
      @request.env['HTTP_ACCEPT'] = 'text/javascript, text/html, application/xml, text/xml, */*'
      returning send!(request_method, action, parameters, session, flash) do
        @request.env.delete 'HTTP_X_REQUESTED_WITH'
        @request.env.delete 'HTTP_ACCEPT'
      end
    end
    alias xhr :xml_http_request

    def follow_redirect
      redirected_controller = @response.redirected_to[:controller]
      if redirected_controller && redirected_controller != @controller.controller_name
        raise "Can't follow redirects outside of current controller (from #{@controller.controller_name} to #{redirected_controller})"
      end

      get(@response.redirected_to.delete(:action), @response.redirected_to.stringify_keys)
    end

    def assigns(key = nil) 
      if key.nil? 
        @response.template.assigns 
      else 
        @response.template.assigns[key.to_s] 
      end 
    end 

    def session
      @response.session
    end

    def flash
      @response.flash
    end

    def cookies
      @response.cookies
    end

    def redirect_to_url
      @response.redirect_url
    end

    def build_request_uri(action, parameters)
      unless @request.env['REQUEST_URI']
        options = @controller.send!(:rewrite_options, parameters)
        options.update(:only_path => true, :action => action)

        url = ActionController::UrlRewriter.new(@request, parameters)
        @request.set_REQUEST_URI(url.rewrite(options))
      end
    end

    def html_document
      xml = @response.content_type =~ /xml$/
      @html_document ||= HTML::Document.new(@response.body, false, xml)
    end

    def find_tag(conditions)
      html_document.find(conditions)
    end

    def find_all_tag(conditions)
      html_document.find_all(conditions)
    end

    def method_missing(selector, *args)
      return @controller.send!(selector, *args) if ActionController::Routing::Routes.named_routes.helpers.include?(selector)
      return super
    end
    
    # Shortcut for ActionController::TestUploadedFile.new(Test::Unit::TestCase.fixture_path + path, type). Example:
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png')
    #
    # To upload binary files on Windows, pass :binary as the last parameter. This will not affect other platforms.
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png', :binary)
    def fixture_file_upload(path, mime_type = nil, binary = false)
      ActionController::TestUploadedFile.new(
        Test::Unit::TestCase.respond_to?(:fixture_path) ? Test::Unit::TestCase.fixture_path + path : path, 
        mime_type,
        binary
      )
    end

    # A helper to make it easier to test different route configurations.
    # This method temporarily replaces ActionController::Routing::Routes
    # with a new RouteSet instance. 
    #
    # The new instance is yielded to the passed block. Typically the block
    # will create some routes using map.draw { map.connect ... }:
    #
    #  with_routing do |set|
    #    set.draw do |map|
    #      map.connect ':controller/:action/:id'
    #        assert_equal(
    #          ['/content/10/show', {}],
    #          map.generate(:controller => 'content', :id => 10, :action => 'show')
    #      end
    #    end
    #  end
    #
    def with_routing
      real_routes = ActionController::Routing::Routes
      ActionController::Routing.module_eval { remove_const :Routes }

      temporary_routes = ActionController::Routing::RouteSet.new
      ActionController::Routing.module_eval { const_set :Routes, temporary_routes }

      yield temporary_routes
    ensure
      if ActionController::Routing.const_defined? :Routes
        ActionController::Routing.module_eval { remove_const :Routes }
      end
      ActionController::Routing.const_set(:Routes, real_routes) if real_routes
    end
  end
end

module Test
  module Unit
    class TestCase #:nodoc:
      include ActionController::TestProcess
    end
  end
end
