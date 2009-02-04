require 'rack/session/abstract/id'
module ActionController #:nodoc:
  class TestRequest < Request #:nodoc:
    attr_accessor :cookies, :session_options
    attr_accessor :query_parameters, :path, :session
    attr_accessor :host

    def self.new(env = {})
      super
    end

    def initialize(env = {})
      super(Rack::MockRequest.env_for("/").merge(env))

      @query_parameters   = {}
      @session            = TestSession.new
      default_rack_options = Rack::Session::Abstract::ID::DEFAULT_OPTIONS
      @session_options    ||= {:id => generate_sid(default_rack_options[:sidbits])}.merge(default_rack_options)

      initialize_default_values
      initialize_containers
    end

    def reset_session
      @session.reset
    end

    # Wraps raw_post in a StringIO.
    def body_stream #:nodoc:
      StringIO.new(raw_post)
    end

    # Either the RAW_POST_DATA environment variable or the URL-encoded request
    # parameters.
    def raw_post
      @env['RAW_POST_DATA'] ||= begin
        data = url_encoded_request_parameters
        data.force_encoding(Encoding::BINARY) if data.respond_to?(:force_encoding)
        data
      end
    end

    def port=(number)
      @env["SERVER_PORT"] = number.to_i
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

    def request_method=(method)
      @request_method = method
    end

    def accept=(mime_types)
      @env["HTTP_ACCEPT"] = Array(mime_types).collect { |mime_types| mime_types.to_s }.join(",")
      @accepts = nil
    end

    def if_modified_since=(last_modified)
      @env["HTTP_IF_MODIFIED_SINCE"] = last_modified
    end

    def if_none_match=(etag)
      @env["HTTP_IF_NONE_MATCH"] = etag
    end

    def remote_addr=(addr)
      @env['REMOTE_ADDR'] = addr
    end

    def request_uri(*args)
      @request_uri || super()
    end

    def path(*args)
      @path || super()
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
      raw_post # populate env['RAW_POST_DATA']
      @parameters = nil # reset TestRequest#parameters to use the new path_parameters
    end

    def recycle!
      @env["action_controller.request.request_parameters"] = {}
      self.query_parameters   = {}
      self.path_parameters    = {}
      @headers, @request_method, @accepts, @content_type = nil, nil, nil, nil
    end

    def user_agent=(user_agent)
      @env['HTTP_USER_AGENT'] = user_agent
    end

    private
      def generate_sid(sidbits)
        "%0#{sidbits / 4}x" % rand(2**sidbits - 1)
      end

      def initialize_containers
        @cookies = {}
      end

      def initialize_default_values
        @host                    = "test.host"
        @request_uri             = "/"
        @env['HTTP_USER_AGENT']  = "Rails Testing"
        @env['REMOTE_ADDR']      = "0.0.0.0"
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
    # The response code of the request
    def response_code
      status.to_s[0,3].to_i rescue 0
    end

    # Returns a String to ensure compatibility with Net::HTTPResponse
    def code
      status.to_s.split(' ')[0]
    end

    def message
      status.to_s.split(' ',2)[1]
    end

    # Was the response successful?
    def success?
      (200..299).include?(response_code)
    end

    # Was the URL not found?
    def missing?
      response_code == 404
    end

    # Were we redirected?
    def redirect?
      (300..399).include?(response_code)
    end

    # Was there a server-side error?
    def error?
      (500..599).include?(response_code)
    end

    alias_method :server_error?, :error?

    # Was there a client client?
    def client_error?
      (400..499).include?(response_code)
    end

    # Returns the redirection location or nil
    def redirect_url
      headers['Location']
    end

    # Does the redirect location match this regexp pattern?
    def redirect_url_match?( pattern )
      return false if redirect_url.nil?
      p = Regexp.new(pattern) if pattern.class == String
      p = pattern if pattern.class == Regexp
      return false if p.nil?
      p.match(redirect_url) != nil
    end

    # Returns the template of the file which was used to
    # render this response (or nil)
    def rendered
      template.instance_variable_get(:@_rendered)
    end

    # A shortcut to the flash. Returns an empty hash if no session flash exists.
    def flash
      session['flash'] || {}
    end

    # Do we have a flash?
    def has_flash?
      !flash.empty?
    end

    # Do we have a flash that has contents?
    def has_flash_with_contents?
      !flash.empty?
    end

    # Does the specified flash object exist?
    def has_flash_object?(name=nil)
      !flash[name].nil?
    end

    # Does the specified object exist in the session?
    def has_session_object?(name=nil)
      !session[name].nil?
    end

    # A shortcut to the template.assigns
    def template_objects
      template.assigns || {}
    end

    # Does the specified template object exist?
    def has_template_object?(name=nil)
      !template_objects[name].nil?
    end

    # Returns the response cookies, converted to a Hash of (name => value) pairs
    #
    #   assert_equal 'AuthorOfNewPage', r.cookies['author']
    def cookies
      cookies = {}
      Array(headers['Set-Cookie']).each do |cookie|
        key, value = cookie.split(";").first.split("=").map {|val| Rack::Utils.unescape(val)}
        cookies[key] = value
      end
      cookies
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

  # Integration test methods such as ActionController::Integration::Session#get
  # and ActionController::Integration::Session#post return objects of class
  # TestResponse, which represent the HTTP response results of the requested
  # controller actions.
  #
  # See Response for more information on controller response objects.
  class TestResponse < Response
    include TestResponseBehavior

    def recycle!
      headers.delete('ETag')
      headers.delete('Last-Modified')
    end
  end

  class TestSession < Hash #:nodoc:
    attr_accessor :session_id

    def initialize(attributes = nil)
      reset_session_id
      replace_attributes(attributes)
    end

    def reset
      reset_session_id
      replace_attributes({ })
    end

    def data
      to_hash
    end

    def [](key)
      super(key.to_s)
    end

    def []=(key, value)
      super(key.to_s, value)
    end

    def update(hash = nil)
      if hash.nil?
        ActiveSupport::Deprecation.warn('use replace instead', caller)
        replace({})
      else
        super(hash)
      end
    end

    def delete(key = nil)
      if key.nil?
        ActiveSupport::Deprecation.warn('use clear instead', caller)
        clear
      else
        super(key.to_s)
      end
    end

    def close
      ActiveSupport::Deprecation.warn('sessions should no longer be closed', caller)
    end

  private

    def reset_session_id
      @session_id = ''
    end

    def replace_attributes(attributes = nil)
      attributes ||= {}
      replace(attributes.stringify_keys)
    end
  end

  # Essentially generates a modified Tempfile object similar to the object
  # you'd get from the standard library CGI module in a multipart
  # request. This means you can use an ActionController::TestUploadedFile
  # object in the params of a test request in order to simulate
  # a file upload.
  #
  # Usage example, within a functional test:
  #   post :change_avatar, :avatar => ActionController::TestUploadedFile.new(ActionController::TestCase.fixture_path + '/files/spongebob.png', 'image/png')
  #
  # Pass a true third parameter to ensure the uploaded file is opened in binary mode (only required for Windows):
  #   post :change_avatar, :avatar => ActionController::TestUploadedFile.new(ActionController::TestCase.fixture_path + '/files/spongebob.png', 'image/png', :binary)
  require 'tempfile'
  class TestUploadedFile
    # The filename, *not* including the path, of the "uploaded" file
    attr_reader :original_filename

    # The content type of the "uploaded" file
    attr_accessor :content_type

    def initialize(path, content_type = Mime::TEXT, binary = false)
      raise "#{path} file does not exist" unless File.exist?(path)
      @content_type = content_type
      @original_filename = path.sub(/^.*#{File::SEPARATOR}([^#{File::SEPARATOR}]+)$/) { $1 }
      @tempfile = Tempfile.new(@original_filename)
      @tempfile.set_encoding(Encoding::BINARY) if @tempfile.respond_to?(:set_encoding)
      @tempfile.binmode if binary
      FileUtils.copy_file(path, @tempfile.path)
    end

    def path #:nodoc:
      @tempfile.path
    end

    alias local_path path

    def method_missing(method_name, *args, &block) #:nodoc:
      @tempfile.__send__(method_name, *args, &block)
    end
  end

  module TestProcess
    def self.included(base)
      # Executes a request simulating GET HTTP method and set/volley the response
      def get(action, parameters = nil, session = nil, flash = nil)
        process(action, parameters, session, flash, "GET")
      end

      # Executes a request simulating POST HTTP method and set/volley the response
      def post(action, parameters = nil, session = nil, flash = nil)
        process(action, parameters, session, flash, "POST")
      end

      # Executes a request simulating PUT HTTP method and set/volley the response
      def put(action, parameters = nil, session = nil, flash = nil)
        process(action, parameters, session, flash, "PUT")
      end

      # Executes a request simulating DELETE HTTP method and set/volley the response
      def delete(action, parameters = nil, session = nil, flash = nil)
        process(action, parameters, session, flash, "DELETE")
      end

      # Executes a request simulating HEAD HTTP method and set/volley the response
      def head(action, parameters = nil, session = nil, flash = nil)
        process(action, parameters, session, flash, "HEAD")
      end
    end

    def process(action, parameters = nil, session = nil, flash = nil, http_method = 'GET')
      # Sanity check for required instance variables so we can give an
      # understandable error message.
      %w(@controller @request @response).each do |iv_name|
        if !(instance_variable_names.include?(iv_name) || instance_variable_names.include?(iv_name.to_sym)) || instance_variable_get(iv_name).nil?
          raise "#{iv_name} is nil: make sure you set it in your test's setup method."
        end
      end

      @request.recycle!
      @response.recycle!

      @html_document = nil
      @request.env['REQUEST_METHOD'] = http_method

      @request.action = action.to_s

      parameters ||= {}
      @request.assign_parameters(@controller.class.controller_path, action.to_s, parameters)

      @request.session = ActionController::TestSession.new(session) unless session.nil?
      @request.session["flash"] = ActionController::Flash::FlashHash.new.update(flash) if flash
      build_request_uri(action, parameters)

      Base.class_eval { include ProcessWithTest } unless Base < ProcessWithTest
      @controller.process_with_test(@request, @response)
    end

    def xml_http_request(request_method, action, parameters = nil, session = nil, flash = nil)
      @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
      @request.env['HTTP_ACCEPT'] =  [Mime::JS, Mime::HTML, Mime::XML, 'text/xml', Mime::ALL].join(', ')
      returning __send__(request_method, action, parameters, session, flash) do
        @request.env.delete 'HTTP_X_REQUESTED_WITH'
        @request.env.delete 'HTTP_ACCEPT'
      end
    end
    alias xhr :xml_http_request

    def assigns(key = nil)
      if key.nil?
        @response.template.assigns
      else
        @response.template.assigns[key.to_s]
      end
    end

    def session
      @request.session
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
        options = @controller.__send__(:rewrite_options, parameters)
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

    def method_missing(selector, *args, &block)
      if @controller && ActionController::Routing::Routes.named_routes.helpers.include?(selector)
        @controller.send(selector, *args, &block)
      else
        super
      end
    end

    # Shortcut for <tt>ActionController::TestUploadedFile.new(ActionController::TestCase.fixture_path + path, type)</tt>:
    #
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png')
    #
    # To upload binary files on Windows, pass <tt>:binary</tt> as the last parameter.
    # This will not affect other platforms:
    #
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png', :binary)
    def fixture_file_upload(path, mime_type = nil, binary = false)
      fixture_path = ActionController::TestCase.send(:fixture_path) if ActionController::TestCase.respond_to?(:fixture_path)
      ActionController::TestUploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
    end

    # A helper to make it easier to test different route configurations.
    # This method temporarily replaces ActionController::Routing::Routes
    # with a new RouteSet instance.
    #
    # The new instance is yielded to the passed block. Typically the block
    # will create some routes using <tt>map.draw { map.connect ... }</tt>:
    #
    #   with_routing do |set|
    #     set.draw do |map|
    #       map.connect ':controller/:action/:id'
    #         assert_equal(
    #           ['/content/10/show', {}],
    #           map.generate(:controller => 'content', :id => 10, :action => 'show')
    #       end
    #     end
    #   end
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

  module ProcessWithTest #:nodoc:
    def self.included(base)
      base.class_eval { attr_reader :assigns }
    end

    def process_with_test(*args)
      process(*args).tap { set_test_assigns }
    end

    private
      def set_test_assigns
        @assigns = {}
        (instance_variable_names - self.class.protected_instance_variables).each do |var|
          name, value = var[1..-1], instance_variable_get(var)
          @assigns[name] = value
          response.template.assigns[name] = value if response
        end
      end
  end
end
