require 'action_dispatch'
require 'rack/session/abstract/id'
require 'active_support/core_ext/object/conversions'

module ActionController #:nodoc:
  class TestRequest < ActionDispatch::TestRequest #:nodoc:
    def initialize(env = {})
      super

      self.session = TestSession.new
      self.session_options = TestSession::DEFAULT_OPTIONS.merge(:id => ActiveSupport::SecureRandom.hex(16))
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

      params = self.request_parameters.dup

      %w(controller action only_path).each do |k|
        params.delete(k)
        params.delete(k.to_sym)
      end

      data = params.to_query
      @env['CONTENT_LENGTH'] = data.length.to_s
      @env['rack.input'] = StringIO.new(data)
    end

    def recycle!
      @formats = nil
      @env.delete_if { |k, v| k =~ /^(action_dispatch|rack)\.request/ }
      @env.delete_if { |k, v| k =~ /^action_dispatch\.rescue/ }
      @env['action_dispatch.request.query_parameters'] = {}
    end
  end

  class TestResponse < ActionDispatch::TestResponse
    def recycle!
      @status = 200
      @header = Rack::Utils::HeaderHash.new
      @writer = lambda { |x| @body << x }
      @block = nil
      @length = 0
      @body = []
      @charset = nil
      @content_type = nil

      @request = @template = nil
    end
  end

  class TestSession < ActionDispatch::Session::AbstractStore::SessionHash #:nodoc:
    DEFAULT_OPTIONS = ActionDispatch::Session::AbstractStore::DEFAULT_OPTIONS

    def initialize(session = {})
      replace(session.stringify_keys)
      @loaded = true
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
  TestUploadedFile = Rack::Utils::Multipart::UploadedFile

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
      @controller.response_body = nil
      @controller.formats = nil
      @controller.params = nil

      @html_document = nil
      @request.env['REQUEST_METHOD'] = http_method

      parameters ||= {}
      @request.assign_parameters(@controller.class.controller_path, action.to_s, parameters)

      @request.session = ActionController::TestSession.new(session) unless session.nil?
      @request.session["flash"] = ActionController::Flash::FlashHash.new.update(flash) if flash

      @controller.request = @request
      @controller.params.merge!(parameters)
      build_request_uri(action, parameters)
      Base.class_eval { include Testing }
      @controller.process_with_new_base_test(@request, @response)
      @response
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
      assigns = {}
      @controller.instance_variable_names.each do |ivar|
        next if ActionController::Base.protected_instance_variables.include?(ivar)
        assigns[ivar[1..-1]] = @controller.instance_variable_get(ivar)
      end

      key.nil? ? assigns : assigns[key.to_s]
    end

    def session
      @request.session
    end

    def flash
      @request.flash
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
        @request.request_uri = url.rewrite(options)
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
end