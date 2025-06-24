# frozen_string_literal: true

# :markup: markdown

require "rack/session/abstract/id"
require "active_support/core_ext/hash/conversions"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/module/anonymous"
require "active_support/core_ext/module/redefine_method"
require "active_support/core_ext/hash/keys"
require "active_support/testing/constant_lookup"
require "action_controller/template_assertions"
require "rails-dom-testing"

module ActionController
  class Metal
    include Testing::Functional
  end

  module Live
    # Disable controller / rendering threads in tests. User tests can access the
    # database on the main thread, so they could open a txn, then the controller
    # thread will open a new connection and try to access data that's only visible
    # to the main thread's txn. This is the problem in #23483.
    alias_method :original_new_controller_thread, :new_controller_thread

    silence_redefinition_of_method :new_controller_thread
    def new_controller_thread # :nodoc:
      yield
    end

    # Because of the above, we need to prevent the clearing of thread locals, since
    # no new thread is actually spawned in the test environment.
    alias_method :original_clean_up_thread_locals, :clean_up_thread_locals

    silence_redefinition_of_method :clean_up_thread_locals
    def clean_up_thread_locals(*args) # :nodoc:
    end

    # Avoid a deadlock from the queue filling up
    Buffer.queue_size = nil
  end

  # ActionController::TestCase will be deprecated and moved to a gem in the
  # future. Please use ActionDispatch::IntegrationTest going forward.
  class TestRequest < ActionDispatch::TestRequest # :nodoc:
    DEFAULT_ENV = ActionDispatch::TestRequest::DEFAULT_ENV.dup
    DEFAULT_ENV.delete "PATH_INFO"

    def self.new_session
      TestSession.new
    end

    attr_reader :controller_class

    # Create a new test request with default `env` values.
    def self.create(controller_class)
      env = {}
      env = Rails.application.env_config.merge(env) if defined?(Rails.application) && Rails.application
      env["rack.request.cookie_hash"] = {}.with_indifferent_access
      new(default_env.merge(env), new_session, controller_class)
    end

    def self.default_env
      DEFAULT_ENV
    end
    private_class_method :default_env

    def initialize(env, session, controller_class)
      super(env)

      self.session = session
      self.session_options = TestSession::DEFAULT_OPTIONS.dup
      @controller_class = controller_class
      @custom_param_parsers = {
        xml: lambda { |raw_post| Hash.from_xml(raw_post)["hash"] }
      }
    end

    def query_string=(string)
      set_header Rack::QUERY_STRING, string
    end

    def content_type=(type)
      set_header "CONTENT_TYPE", type
    end

    def assign_parameters(routes, controller_path, action, parameters, generated_path, query_string_keys)
      non_path_parameters = {}
      path_parameters = {}

      parameters.each do |key, value|
        if query_string_keys.include?(key)
          non_path_parameters[key] = value
        else
          if value.is_a?(Array)
            value = value.map(&:to_param)
          else
            value = value.to_param
          end

          path_parameters[key.to_sym] = value
        end
      end

      if get?
        if query_string.blank?
          self.query_string = non_path_parameters.to_query
        end
      else
        if ENCODER.should_multipart?(non_path_parameters)
          self.content_type = ENCODER.content_type
          data = ENCODER.build_multipart non_path_parameters
        else
          fetch_header("CONTENT_TYPE") do |k|
            set_header k, "application/x-www-form-urlencoded"
          end

          case content_mime_type&.to_sym
          when nil
            raise "Unknown Content-Type: #{content_type}"
          when :json
            data = ActiveSupport::JSON.encode(non_path_parameters)
          when :xml
            data = non_path_parameters.to_xml
          when :url_encoded_form
            data = non_path_parameters.to_query
          else
            @custom_param_parsers[content_mime_type.symbol] = ->(_) { non_path_parameters }
            data = non_path_parameters.to_query
          end
        end

        data_stream = StringIO.new(data.b)
        set_header "CONTENT_LENGTH", data_stream.length.to_s
        set_header "rack.input", data_stream
      end

      fetch_header("PATH_INFO") do |k|
        set_header k, generated_path
      end
      fetch_header("ORIGINAL_FULLPATH") do |k|
        set_header k, fullpath
      end
      path_parameters[:controller] = controller_path
      path_parameters[:action] = action

      self.path_parameters = path_parameters
    end

    ENCODER = Class.new do
      include Rack::Test::Utils

      def should_multipart?(params)
        # FIXME: lifted from Rack-Test. We should push this separation upstream.
        multipart = false
        query = lambda { |value|
          case value
          when Array
            value.each(&query)
          when Hash
            value.values.each(&query)
          when Rack::Test::UploadedFile
            multipart = true
          end
        }
        params.values.each(&query)
        multipart
      end

      public :build_multipart

      def content_type
        "multipart/form-data; boundary=#{Rack::Test::MULTIPART_BOUNDARY}"
      end
    end.new

    private
      def params_parsers
        super.merge @custom_param_parsers
      end
  end

  class LiveTestResponse < Live::Response
    # Was the response successful?
    alias_method :success?, :successful?

    # Was the URL not found?
    alias_method :missing?, :not_found?

    # Was there a server-side error?
    alias_method :error?, :server_error?
  end

  # Methods #destroy and #load! are overridden to avoid calling methods on the
  # @store object, which does not exist for the TestSession class.
  class TestSession < Rack::Session::Abstract::PersistedSecure::SecureSessionHash # :nodoc:
    DEFAULT_OPTIONS = Rack::Session::Abstract::Persisted::DEFAULT_OPTIONS

    def initialize(session = {}, id = Rack::Session::SessionId.new(SecureRandom.hex(16)))
      super(nil, nil)
      @id = id
      @data = stringify_keys(session)
      @loaded = true
      @initially_empty = @data.empty?
    end

    def exists?
      true
    end

    def keys
      @data.keys
    end

    def values
      @data.values
    end

    def destroy
      clear
    end

    def dig(*keys)
      keys = keys.map.with_index { |key, i| i.zero? ? key.to_s : key }
      @data.dig(*keys)
    end

    def fetch(key, *args, &block)
      @data.fetch(key.to_s, *args, &block)
    end

    def enabled?
      true
    end

    def id_was
      @id
    end

    private
      def load!
        @id
      end
  end

  # # Action Controller Test Case
  #
  # Superclass for ActionController functional tests. Functional tests allow you
  # to test a single controller action per test method.
  #
  # ## Use integration style controller tests over functional style controller tests.
  #
  # Rails discourages the use of functional tests in favor of integration tests
  # (use ActionDispatch::IntegrationTest).
  #
  # New Rails applications no longer generate functional style controller tests
  # and they should only be used for backward compatibility. Integration style
  # controller tests perform actual requests, whereas functional style controller
  # tests merely simulate a request. Besides, integration tests are as fast as
  # functional tests and provide lot of helpers such as `as`, `parsed_body` for
  # effective testing of controller actions including even API endpoints.
  #
  # ## Basic example
  #
  # Functional tests are written as follows:
  # 1.  First, one uses the `get`, `post`, `patch`, `put`, `delete`, or `head`
  #     method to simulate an HTTP request.
  # 2.  Then, one asserts whether the current state is as expected. "State" can be
  #     anything: the controller's HTTP response, the database contents, etc.
  #
  #
  # For example:
  #
  #     class BooksControllerTest < ActionController::TestCase
  #       def test_create
  #         # Simulate a POST response with the given HTTP parameters.
  #         post(:create, params: { book: { title: "Love Hina" }})
  #
  #         # Asserts that the controller tried to redirect us to
  #         # the created book's URI.
  #         assert_response :found
  #
  #         # Asserts that the controller really put the book in the database.
  #         assert_not_nil Book.find_by(title: "Love Hina")
  #       end
  #     end
  #
  # You can also send a real document in the simulated HTTP request.
  #
  #     def test_create
  #       json = {book: { title: "Love Hina" }}.to_json
  #       post :create, body: json
  #     end
  #
  # ## Special instance variables
  #
  # ActionController::TestCase will also automatically provide the following
  # instance variables for use in the tests:
  #
  # @controller
  # :   The controller instance that will be tested.
  #
  # @request
  # :   An ActionController::TestRequest, representing the current HTTP request.
  #     You can modify this object before sending the HTTP request. For example,
  #     you might want to set some session properties before sending a GET
  #     request.
  #
  # @response
  # :   An ActionDispatch::TestResponse object, representing the response of the
  #     last HTTP response. In the above example, `@response` becomes valid after
  #     calling `post`. If the various assert methods are not sufficient, then you
  #     may use this object to inspect the HTTP response in detail.
  #
  #
  # ## Controller is automatically inferred
  #
  # ActionController::TestCase will automatically infer the controller under test
  # from the test class name. If the controller cannot be inferred from the test
  # class name, you can explicitly set it with `tests`.
  #
  #     class SpecialEdgeCaseWidgetsControllerTest < ActionController::TestCase
  #       tests WidgetController
  #     end
  #
  # ## Testing controller internals
  #
  # In addition to these specific assertions, you also have easy access to various
  # collections that the regular test/unit assertions can be used against. These
  # collections are:
  #
  # *   session: Objects being saved in the session.
  # *   flash: The flash objects currently in the session.
  # *   cookies: Cookies being sent to the user on this request.
  #
  #
  # These collections can be used just like any other hash:
  #
  #     assert_equal "Dave", cookies[:name] # makes sure that a cookie called :name was set as "Dave"
  #     assert flash.empty? # makes sure that there's nothing in the flash
  #
  # On top of the collections, you have the complete URL that a given action
  # redirected to available in `redirect_to_url`.
  #
  # For redirects within the same controller, you can even call follow_redirect
  # and the redirect will be followed, triggering another action call which can
  # then be asserted against.
  #
  # ## Manipulating session and cookie variables
  #
  # Sometimes you need to set up the session and cookie variables for a test. To
  # do this just assign a value to the session or cookie collection:
  #
  #     session[:key] = "value"
  #     cookies[:key] = "value"
  #
  # To clear the cookies for a test just clear the cookie collection:
  #
  #     cookies.clear
  #
  # ## Testing named routes
  #
  # If you're using named routes, they can be easily tested using the original
  # named routes' methods straight in the test case.
  #
  #     assert_redirected_to page_url(title: 'foo')
  class TestCase < ActiveSupport::TestCase
    singleton_class.attr_accessor :executor_around_each_request

    module Behavior
      extend ActiveSupport::Concern
      include ActionDispatch::TestProcess
      include ActiveSupport::Testing::ConstantLookup
      include Rails::Dom::Testing::Assertions

      attr_reader :response, :request

      module ClassMethods
        # Sets the controller class name. Useful if the name can't be inferred from test
        # class. Normalizes `controller_class` before using.
        #
        #     tests WidgetController
        #     tests :widget
        #     tests 'widget'
        def tests(controller_class)
          case controller_class
          when String, Symbol
            self.controller_class = "#{controller_class.to_s.camelize}Controller".constantize
          when Class
            self.controller_class = controller_class
          else
            raise ArgumentError, "controller class must be a String, Symbol, or Class"
          end
        end

        def controller_class=(new_class)
          self._controller_class = new_class
        end

        def controller_class
          if current_controller_class = _controller_class
            current_controller_class
          else
            self.controller_class = determine_default_controller_class(name)
          end
        end

        def determine_default_controller_class(name)
          determine_constant_from_test_name(name) do |constant|
            Class === constant && constant < ActionController::Metal
          end
        end
      end

      # Simulate a GET request with the given parameters.
      #
      # *   `action`: The controller action to call.
      # *   `params`: The hash with HTTP parameters that you want to pass. This may be
      #     `nil`.
      # *   `body`: The request body with a string that is appropriately encoded
      #     (`application/x-www-form-urlencoded` or `multipart/form-data`).
      # *   `session`: A hash of parameters to store in the session. This may be
      #     `nil`.
      # *   `flash`: A hash of parameters to store in the flash. This may be `nil`.
      #
      #
      # You can also simulate POST, PATCH, PUT, DELETE, and HEAD requests with `post`,
      # `patch`, `put`, `delete`, and `head`. Example sending parameters, session, and
      # setting a flash message:
      #
      #     get :show,
      #       params: { id: 7 },
      #       session: { user_id: 1 },
      #       flash: { notice: 'This is flash message' }
      #
      # Note that the request method is not verified. The different methods are
      # available to make the tests more expressive.
      def get(action, **args)
        process(action, method: "GET", **args)
      end

      # Simulate a POST request with the given parameters and set/volley the response.
      # See `get` for more details.
      def post(action, **args)
        process(action, method: "POST", **args)
      end

      # Simulate a PATCH request with the given parameters and set/volley the
      # response. See `get` for more details.
      def patch(action, **args)
        process(action, method: "PATCH", **args)
      end

      # Simulate a PUT request with the given parameters and set/volley the response.
      # See `get` for more details.
      def put(action, **args)
        process(action, method: "PUT", **args)
      end

      # Simulate a DELETE request with the given parameters and set/volley the
      # response. See `get` for more details.
      def delete(action, **args)
        process(action, method: "DELETE", **args)
      end

      # Simulate a HEAD request with the given parameters and set/volley the response.
      # See `get` for more details.
      def head(action, **args)
        process(action, method: "HEAD", **args)
      end

      # Simulate an HTTP request to `action` by specifying request method, parameters
      # and set/volley the response.
      #
      # *   `action`: The controller action to call.
      # *   `method`: Request method used to send the HTTP request. Possible values
      #     are `GET`, `POST`, `PATCH`, `PUT`, `DELETE`, `HEAD`. Defaults to `GET`.
      #     Can be a symbol.
      # *   `params`: The hash with HTTP parameters that you want to pass. This may be
      #     `nil`.
      # *   `body`: The request body with a string that is appropriately encoded
      #     (`application/x-www-form-urlencoded` or `multipart/form-data`).
      # *   `session`: A hash of parameters to store in the session. This may be
      #     `nil`.
      # *   `flash`: A hash of parameters to store in the flash. This may be `nil`.
      # *   `format`: Request format. Defaults to `nil`. Can be string or symbol.
      # *   `as`: Content type. Defaults to `nil`. Must be a symbol that corresponds
      #     to a mime type.
      #
      #
      # Example calling `create` action and sending two params:
      #
      #     process :create,
      #       method: 'POST',
      #       params: {
      #         user: { name: 'Gaurish Sharma', email: 'user@example.com' }
      #       },
      #       session: { user_id: 1 },
      #       flash: { notice: 'This is flash message' }
      #
      # To simulate `GET`, `POST`, `PATCH`, `PUT`, `DELETE`, and `HEAD` requests
      # prefer using #get, #post, #patch, #put, #delete and #head methods respectively
      # which will make tests more expressive.
      #
      # It's not recommended to make more than one request in the same test. Instance
      # variables that are set in one request will not persist to the next request,
      # but it's not guaranteed that all Rails internal state will be reset. Prefer
      # ActionDispatch::IntegrationTest for making multiple requests in the same test.
      #
      # Note that the request method is not verified.
      def process(action, method: "GET", params: nil, session: nil, body: nil, flash: {}, format: nil, xhr: false, as: nil)
        check_required_ivars
        @controller.clear_instance_variables_between_requests

        action = +action.to_s
        http_method = method.to_s.upcase

        @html_document = nil

        cookies.update(@request.cookies)
        cookies.update_cookies_from_jar
        @request.set_header "HTTP_COOKIE", cookies.to_header
        @request.delete_header "action_dispatch.cookies"

        @request          = TestRequest.new scrub_env!(@request.env), @request.session, @controller.class
        @response         = build_response @response_klass
        @response.request = @request
        @controller.recycle!

        if body
          @request.set_header "RAW_POST_DATA", body
        end

        @request.set_header "REQUEST_METHOD", http_method

        if as
          @request.content_type = Mime[as].to_s
          format ||= as
        end

        parameters = (params || {}).symbolize_keys

        if format
          parameters[:format] = format
        end

        setup_request(controller_class_name, action, parameters, session, flash, xhr)
        process_controller_response(action, cookies, xhr)
      end

      def controller_class_name
        @controller.class.anonymous? ? "anonymous" : @controller.class.controller_path
      end

      def generated_path(generated_extras)
        generated_extras[0]
      end

      def query_parameter_names(generated_extras)
        generated_extras[1] + [:controller, :action]
      end

      def setup_controller_request_and_response
        @controller = nil unless defined? @controller

        @response_klass = ActionDispatch::TestResponse

        if klass = self.class.controller_class
          if klass < ActionController::Live
            @response_klass = LiveTestResponse
          end
          unless @controller
            begin
              @controller = klass.new
            rescue
              warn "could not construct controller #{klass}" if $VERBOSE
            end
          end
        end

        @request          = TestRequest.create(@controller.class)
        @response         = build_response @response_klass
        @response.request = @request

        if @controller
          @controller.request = @request
          @controller.params = {}
        end
      end

      def build_response(klass)
        klass.create
      end

      included do
        include ActionController::TemplateAssertions
        include ActionDispatch::Assertions
        class_attribute :_controller_class
        setup :setup_controller_request_and_response
        ActiveSupport.run_load_hooks(:action_controller_test_case, self)
      end

      private
        def setup_request(controller_class_name, action, parameters, session, flash, xhr)
          generated_extras = @routes.generate_extras(parameters.merge(controller: controller_class_name, action: action))
          generated_path = generated_path(generated_extras)
          query_string_keys = query_parameter_names(generated_extras)

          @request.assign_parameters(@routes, controller_class_name, action, parameters, generated_path, query_string_keys)

          @request.session.update(session) if session
          @request.flash.update(flash || {})

          if xhr
            @request.set_header "HTTP_X_REQUESTED_WITH", "XMLHttpRequest"
            @request.fetch_header("HTTP_ACCEPT") do |k|
              @request.set_header k, [Mime[:js], Mime[:html], Mime[:xml], "text/xml", "*/*"].join(", ")
            end
          end

          @request.fetch_header("SCRIPT_NAME") do |k|
            @request.set_header k, @controller.config.relative_url_root
          end
        end

        def wrap_execution(&block)
          if ActionController::TestCase.executor_around_each_request && defined?(Rails.application) && Rails.application
            Rails.application.executor.wrap(&block)
          else
            yield
          end
        end

        def process_controller_response(action, cookies, xhr)
          begin
            @controller.recycle!

            wrap_execution { @controller.dispatch(action, @request, @response) }
          ensure
            @request = @controller.request
            @response = @controller.response

            if @request.have_cookie_jar?
              unless @request.cookie_jar.committed?
                @request.cookie_jar.write(@response)
                cookies.update(@request.cookie_jar.instance_variable_get(:@cookies))
                cookies.update(@response.cookies)
              end
            end
            @response.prepare!

            if flash_value = @request.flash.to_session_value
              @request.session["flash"] = flash_value
            else
              @request.session.delete("flash")
            end

            if xhr
              @request.delete_header "HTTP_X_REQUESTED_WITH"
              @request.delete_header "HTTP_ACCEPT"
            end
            @request.query_string = ""

            @response.sent!
          end

          @response
        end

        def scrub_env!(env)
          env.delete_if do |k, _|
            k.start_with?("rack.request", "action_dispatch.request", "action_dispatch.rescue")
          end
          env["rack.input"] = StringIO.new
          env.delete "CONTENT_LENGTH"
          env.delete "RAW_POST_DATA"
          env
        end

        def document_root_element
          html_document.root
        end

        def check_required_ivars
          # Check for required instance variables so we can give an understandable error
          # message.
          [:@routes, :@controller, :@request, :@response].each do |iv_name|
            if !instance_variable_defined?(iv_name) || instance_variable_get(iv_name).nil?
              raise "#{iv_name} is nil: make sure you set it in your test's setup method."
            end
          end
        end
    end

    include Behavior
  end
end
