require 'rack/session/abstract/id'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/hash/keys'
require 'action_controller/template_assertions'
require 'rails-dom-testing'

module ActionController
  class TestRequest < ActionDispatch::TestRequest #:nodoc:
    DEFAULT_ENV = ActionDispatch::TestRequest::DEFAULT_ENV.dup
    DEFAULT_ENV.delete 'PATH_INFO'

    def initialize(env = {})
      super

      self.session = TestSession.new
      self.session_options = TestSession::DEFAULT_OPTIONS
    end

    def assign_parameters(routes, controller_path, action, parameters = {})
      parameters = parameters.symbolize_keys
      extra_keys = routes.extra_keys(parameters.merge(:controller => controller_path, :action => action))
      non_path_parameters = get? ? query_parameters : request_parameters

      parameters.each do |key, value|
        if value.is_a?(Array) && (value.frozen? || value.any?(&:frozen?))
          value = value.map{ |v| v.duplicable? ? v.dup : v }
        elsif value.is_a?(Hash) && (value.frozen? || value.any?{ |k,v| v.frozen? })
          value = Hash[value.map{ |k,v| [k, v.duplicable? ? v.dup : v] }]
        elsif value.frozen? && value.duplicable?
          value = value.dup
        end

        if extra_keys.include?(key) || key == :action || key == :controller
          non_path_parameters[key] = value
        else
          if value.is_a?(Array)
            value = value.map(&:to_param)
          else
            value = value.to_param
          end

          path_parameters[key] = value
        end
      end

      path_parameters[:controller] = controller_path
      path_parameters[:action] = action

      # Clear the combined params hash in case it was already referenced.
      @env.delete("action_dispatch.request.parameters")

      # Clear the filter cache variables so they're not stale
      @filtered_parameters = @filtered_env = @filtered_path = nil

      data = request_parameters.to_query
      @env['CONTENT_LENGTH'] = data.length.to_s
      @env['rack.input'] = StringIO.new(data)
    end

    def recycle!
      @formats = nil
      @env.delete_if { |k, v| k =~ /^(action_dispatch|rack)\.request/ }
      @env.delete_if { |k, v| k =~ /^action_dispatch\.rescue/ }
      @method = @request_method = nil
      @fullpath = @ip = @remote_ip = @protocol = nil
      @env['action_dispatch.request.query_parameters'] = {}
      @set_cookies ||= {}
      @set_cookies.update(Hash[cookie_jar.instance_variable_get("@set_cookies").map{ |k,o| [k,o[:value]] }])
      deleted_cookies = cookie_jar.instance_variable_get("@delete_cookies")
      @set_cookies.reject!{ |k,v| deleted_cookies.include?(k) }
      cookie_jar.update(rack_cookies)
      cookie_jar.update(cookies)
      cookie_jar.update(@set_cookies)
      cookie_jar.recycle!
    end

    private

    def default_env
      DEFAULT_ENV
    end
  end

  class TestResponse < ActionDispatch::TestResponse
    def recycle!
      initialize
    end
  end

  class LiveTestResponse < Live::Response
    def recycle!
      @body = nil
      initialize
    end

    def body
      @body ||= super
    end

    # Was the response successful?
    alias_method :success?, :successful?

    # Was the URL not found?
    alias_method :missing?, :not_found?

    # Were we redirected?
    alias_method :redirect?, :redirection?

    # Was there a server-side error?
    alias_method :error?, :server_error?
  end

  # Methods #destroy and #load! are overridden to avoid calling methods on the
  # @store object, which does not exist for the TestSession class.
  class TestSession < Rack::Session::Abstract::SessionHash #:nodoc:
    DEFAULT_OPTIONS = Rack::Session::Abstract::ID::DEFAULT_OPTIONS

    def initialize(session = {})
      super(nil, nil)
      @id = SecureRandom.hex(16)
      @data = stringify_keys(session)
      @loaded = true
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

    private

      def load!
        @id
      end
  end

  # Superclass for ActionController functional tests. Functional tests allow you to
  # test a single controller action per test method. This should not be confused with
  # integration tests (see ActionDispatch::IntegrationTest), which are more like
  # "stories" that can involve multiple controllers and multiple actions (i.e. multiple
  # different HTTP requests).
  #
  # == Basic example
  #
  # Functional tests are written as follows:
  # 1. First, one uses the +get+, +post+, +patch+, +put+, +delete+ or +head+ method to simulate
  #    an HTTP request.
  # 2. Then, one asserts whether the current state is as expected. "State" can be anything:
  #    the controller's HTTP response, the database contents, etc.
  #
  # For example:
  #
  #   class BooksControllerTest < ActionController::TestCase
  #     def test_create
  #       # Simulate a POST response with the given HTTP parameters.
  #       post(:create, params: { book: { title: "Love Hina" }})
  #
  #       # Assert that the controller tried to redirect us to
  #       # the created book's URI.
  #       assert_response :found
  #
  #       # Assert that the controller really put the book in the database.
  #       assert_not_nil Book.find_by(title: "Love Hina")
  #     end
  #   end
  #
  # You can also send a real document in the simulated HTTP request.
  #
  #   def test_create
  #     json = {book: { title: "Love Hina" }}.to_json
  #     post :create, json
  #   end
  #
  # == Special instance variables
  #
  # ActionController::TestCase will also automatically provide the following instance
  # variables for use in the tests:
  #
  # <b>@controller</b>::
  #      The controller instance that will be tested.
  # <b>@request</b>::
  #      An ActionController::TestRequest, representing the current HTTP
  #      request. You can modify this object before sending the HTTP request. For example,
  #      you might want to set some session properties before sending a GET request.
  # <b>@response</b>::
  #      An ActionController::TestResponse object, representing the response
  #      of the last HTTP response. In the above example, <tt>@response</tt> becomes valid
  #      after calling +post+. If the various assert methods are not sufficient, then you
  #      may use this object to inspect the HTTP response in detail.
  #
  # (Earlier versions of \Rails required each functional test to subclass
  # Test::Unit::TestCase and define @controller, @request, @response in +setup+.)
  #
  # == Controller is automatically inferred
  #
  # ActionController::TestCase will automatically infer the controller under test
  # from the test class name. If the controller cannot be inferred from the test
  # class name, you can explicitly set it with +tests+.
  #
  #   class SpecialEdgeCaseWidgetsControllerTest < ActionController::TestCase
  #     tests WidgetController
  #   end
  #
  # == \Testing controller internals
  #
  # In addition to these specific assertions, you also have easy access to various collections that the regular test/unit assertions
  # can be used against. These collections are:
  #
  # * session: Objects being saved in the session.
  # * flash: The flash objects currently in the session.
  # * cookies: \Cookies being sent to the user on this request.
  #
  # These collections can be used just like any other hash:
  #
  #   assert_equal "Dave", cookies[:name] # makes sure that a cookie called :name was set as "Dave"
  #   assert flash.empty? # makes sure that there's nothing in the flash
  #
  # On top of the collections, you have the complete url that a given action redirected to available in <tt>redirect_to_url</tt>.
  #
  # For redirects within the same controller, you can even call follow_redirect and the redirect will be followed, triggering another
  # action call which can then be asserted against.
  #
  # == Manipulating session and cookie variables
  #
  # Sometimes you need to set up the session and cookie variables for a test.
  # To do this just assign a value to the session or cookie collection:
  #
  #   session[:key] = "value"
  #   cookies[:key] = "value"
  #
  # To clear the cookies for a test just clear the cookie collection:
  #
  #   cookies.clear
  #
  # == \Testing named routes
  #
  # If you're using named routes, they can be easily tested using the original named routes' methods straight in the test case.
  #
  #  assert_redirected_to page_url(title: 'foo')
  class TestCase < ActiveSupport::TestCase
    module Behavior
      extend ActiveSupport::Concern
      include ActionDispatch::TestProcess
      include ActiveSupport::Testing::ConstantLookup
      include Rails::Dom::Testing::Assertions

      attr_reader :response, :request

      module ClassMethods

        # Sets the controller class name. Useful if the name can't be inferred from test class.
        # Normalizes +controller_class+ before using.
        #
        #   tests WidgetController
        #   tests :widget
        #   tests 'widget'
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
          if current_controller_class = self._controller_class
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
      # - +action+: The controller action to call.
      # - +params+: The hash with HTTP parameters that you want to pass. This may be +nil+.
      # - +body+: The request body with a string that is appropriately encoded
      #   (<tt>application/x-www-form-urlencoded</tt> or <tt>multipart/form-data</tt>).
      # - +session+: A hash of parameters to store in the session. This may be +nil+.
      # - +flash+: A hash of parameters to store in the flash. This may be +nil+.
      #
      # You can also simulate POST, PATCH, PUT, DELETE, and HEAD requests with
      # +post+, +patch+, +put+, +delete+, and +head+.
      # Example sending parameters, session and setting a flash message:
      #
      #   get :show,
      #     params: { id: 7 },
      #     session: { user_id: 1 },
      #     flash: { notice: 'This is flash message' }
      #
      # Note that the request method is not verified. The different methods are
      # available to make the tests more expressive.
      def get(action, *args)
        res = process_with_kwargs("GET", action, *args)
        cookies.update res.cookies
        res
      end

      # Simulate a POST request with the given parameters and set/volley the response.
      # See +get+ for more details.
      def post(action, *args)
        process_with_kwargs("POST", action, *args)
      end

      # Simulate a PATCH request with the given parameters and set/volley the response.
      # See +get+ for more details.
      def patch(action, *args)
        process_with_kwargs("PATCH", action, *args)
      end

      # Simulate a PUT request with the given parameters and set/volley the response.
      # See +get+ for more details.
      def put(action, *args)
        process_with_kwargs("PUT", action, *args)
      end

      # Simulate a DELETE request with the given parameters and set/volley the response.
      # See +get+ for more details.
      def delete(action, *args)
        process_with_kwargs("DELETE", action, *args)
      end

      # Simulate a HEAD request with the given parameters and set/volley the response.
      # See +get+ for more details.
      def head(action, *args)
        process_with_kwargs("HEAD", action, *args)
      end

      def xml_http_request(*args)
        ActiveSupport::Deprecation.warn(<<-MSG.strip_heredoc)
          xhr and xml_http_request methods are deprecated in favor of
          `get :index, xhr: true` and `post :create, xhr: true`
        MSG

        @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
        @request.env['HTTP_ACCEPT'] ||= [Mime::JS, Mime::HTML, Mime::XML, 'text/xml', Mime::ALL].join(', ')
        __send__(*args).tap do
          @request.env.delete 'HTTP_X_REQUESTED_WITH'
          @request.env.delete 'HTTP_ACCEPT'
        end
      end
      alias xhr :xml_http_request

      def paramify_values(hash_or_array_or_value)
        case hash_or_array_or_value
        when Hash
          Hash[hash_or_array_or_value.map{|key, value| [key, paramify_values(value)] }]
        when Array
          hash_or_array_or_value.map {|i| paramify_values(i)}
        when Rack::Test::UploadedFile, ActionDispatch::Http::UploadedFile
          hash_or_array_or_value
        else
          hash_or_array_or_value.to_param
        end
      end

      # Simulate a HTTP request to +action+ by specifying request method,
      # parameters and set/volley the response.
      #
      # - +action+: The controller action to call.
      # - +method+: Request method used to send the HTTP request. Possible values
      #   are +GET+, +POST+, +PATCH+, +PUT+, +DELETE+, +HEAD+. Defaults to +GET+. Can be a symbol.
      # - +params+: The hash with HTTP parameters that you want to pass. This may be +nil+.
      # - +body+: The request body with a string that is appropriately encoded
      #   (<tt>application/x-www-form-urlencoded</tt> or <tt>multipart/form-data</tt>).
      # - +session+: A hash of parameters to store in the session. This may be +nil+.
      # - +flash+: A hash of parameters to store in the flash. This may be +nil+.
      # - +format+: Request format. Defaults to +nil+. Can be string or symbol.
      #
      # Example calling +create+ action and sending two params:
      #
      #   process :create,
      #     method: 'POST',
      #     params: {
      #       user: { name: 'Gaurish Sharma', email: 'user@example.com' }
      #     },
      #     session: { user_id: 1 },
      #     flash: { notice: 'This is flash message' }
      #
      # To simulate +GET+, +POST+, +PATCH+, +PUT+, +DELETE+ and +HEAD+ requests
      # prefer using #get, #post, #patch, #put, #delete and #head methods
      # respectively which will make tests more expressive.
      #
      # Note that the request method is not verified.
      def process(action, *args)
        check_required_ivars

        if kwarg_request?(args)
          parameters, session, body, flash, http_method, format, xhr = args[0].values_at(:params, :session, :body, :flash, :method, :format, :xhr)
        else
          http_method, parameters, session, flash = args
          format = nil

          if parameters.is_a?(String) && http_method != 'HEAD'
            body = parameters
            parameters = nil
          end

          if parameters.present? || session.present? || flash.present?
            non_kwarg_request_warning
          end
        end

        if body.present?
          @request.env['RAW_POST_DATA'] = body
        end

        if http_method.present?
          http_method = http_method.to_s.upcase
        else
          http_method = "GET"
        end

        parameters ||= {}

        # Ensure that numbers and symbols passed as params are converted to
        # proper params, as is the case when engaging rack.
        parameters = paramify_values(parameters) if html_format?(parameters)

        if format.present?
          parameters[:format] = format
        end

        @html_document = nil

        unless @controller.respond_to?(:recycle!)
          @controller.extend(Testing::Functional)
        end

        @request.recycle!
        @response.recycle!
        @controller.recycle!

        @request.env['REQUEST_METHOD'] = http_method

        controller_class_name = @controller.class.anonymous? ?
          "anonymous" :
          @controller.class.controller_path

        @request.assign_parameters(@routes, controller_class_name, action.to_s, parameters)

        @request.session.update(session) if session
        @request.flash.update(flash || {})

        if xhr
          @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
          @request.env['HTTP_ACCEPT'] ||= [Mime::JS, Mime::HTML, Mime::XML, 'text/xml', Mime::ALL].join(', ')
        end

        @controller.request  = @request
        @controller.response = @response

        build_request_uri(controller_class_name, action, parameters)

        @controller.recycle!
        @controller.process(action)

        if cookies = @request.env['action_dispatch.cookies']
          unless @response.committed?
            cookies.write(@response)
            self.cookies.update(cookies.instance_variable_get(:@cookies))
          end
        end
        @response.prepare!

        if flash_value = @request.flash.to_session_value
          @request.session['flash'] = flash_value
        else
          @request.session.delete('flash')
        end

        if xhr
          @request.env.delete 'HTTP_X_REQUESTED_WITH'
          @request.env.delete 'HTTP_ACCEPT'
        end

        @response
      end

      def setup_controller_request_and_response
        @controller = nil unless defined? @controller

        response_klass = TestResponse

        if klass = self.class.controller_class
          if klass < ActionController::Live
            response_klass = LiveTestResponse
          end
          unless @controller
            begin
              @controller = klass.new
            rescue
              warn "could not construct controller #{klass}" if $VERBOSE
            end
          end
        end

        @request          = build_request
        @response         = build_response response_klass
        @response.request = @request

        if @controller
          @controller.request = @request
          @controller.params = {}
        end
      end

      def build_request
        TestRequest.new
      end

      def build_response(klass)
        klass.new
      end

      included do
        include ActionController::TemplateAssertions
        include ActionDispatch::Assertions
        class_attribute :_controller_class
        setup :setup_controller_request_and_response
      end

      private

      def process_with_kwargs(http_method, action, *args)
        if kwarg_request?(args)
          args.first.merge!(method: http_method)
          process(action, *args)
        else
          non_kwarg_request_warning if args.any?

          args = args.unshift(http_method)
          process(action, *args)
        end
      end

      REQUEST_KWARGS = %i(params session flash method body xhr)
      def kwarg_request?(args)
        args[0].respond_to?(:keys) && (
          (args[0].key?(:format) && args[0].keys.size == 1) ||
          args[0].keys.any? { |k| REQUEST_KWARGS.include?(k) }
        )
      end

      def non_kwarg_request_warning
        ActiveSupport::Deprecation.warn(<<-MSG.strip_heredoc)
          ActionController::TestCase HTTP request methods will accept only
          keyword arguments in future Rails versions.

          Examples:

          get :show, params: { id: 1 }, session: { user_id: 1 }
          process :update, method: :post, params: { id: 1 }
        MSG
      end

      def document_root_element
        html_document.root
      end

      def check_required_ivars
        # Sanity check for required instance variables so we can give an
        # understandable error message.
        [:@routes, :@controller, :@request, :@response].each do |iv_name|
          if !instance_variable_defined?(iv_name) || instance_variable_get(iv_name).nil?
            raise "#{iv_name} is nil: make sure you set it in your test's setup method."
          end
        end
      end

      def build_request_uri(controller_class_name, action, parameters)
        unless @request.env["PATH_INFO"]
          options = @controller.respond_to?(:url_options) ? @controller.__send__(:url_options).merge(parameters) : parameters
          options.update(
            :controller => controller_class_name,
            :action => action,
            :relative_url_root => nil,
            :_recall => @request.path_parameters)

          url, query_string = @routes.path_for(options).split("?", 2)

          @request.env["SCRIPT_NAME"] = @controller.config.relative_url_root
          @request.env["PATH_INFO"] = url
          @request.env["QUERY_STRING"] = query_string || ""
        end
      end

      def html_format?(parameters)
        return true unless parameters.key?(:format)
        Mime.fetch(parameters[:format]) { Mime['html'] }.html?
      end
    end

    include Behavior
  end
end
