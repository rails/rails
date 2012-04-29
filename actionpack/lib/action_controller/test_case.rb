require 'rack/session/abstract/id'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/module/anonymous'

module ActionController
  module TemplateAssertions
    extend ActiveSupport::Concern

    included do
      setup :setup_subscriptions
      teardown :teardown_subscriptions
    end

    def setup_subscriptions
      @partials = Hash.new(0)
      @templates = Hash.new(0)
      @layouts = Hash.new(0)

      ActiveSupport::Notifications.subscribe("render_template.action_view") do |name, start, finish, id, payload|
        path = payload[:layout]
        @layouts[path] += 1
      end

      ActiveSupport::Notifications.subscribe("!render_template.action_view") do |name, start, finish, id, payload|
        path = payload[:virtual_path]
        next unless path
        partial = path =~ /^.*\/_[^\/]*$/
        if partial
          @partials[path] += 1
          @partials[path.split("/").last] += 1
          @templates[path] += 1
        else
          @templates[path] += 1
        end
      end
    end

    def teardown_subscriptions
      ActiveSupport::Notifications.unsubscribe("render_template.action_view")
      ActiveSupport::Notifications.unsubscribe("!render_template.action_view")
    end

    def process(*args)
      @partials = Hash.new(0)
      @templates = Hash.new(0)
      @layouts = Hash.new(0)
      super
    end

    # Asserts that the request was rendered with the appropriate template file or partials.
    #
    # ==== Examples
    #
    #   # assert that the "new" view template was rendered
    #   assert_template "new"
    #
    #   # assert that the "_customer" partial was rendered twice
    #   assert_template :partial => '_customer', :count => 2
    #
    #   # assert that no partials were rendered
    #   assert_template :partial => false
    #
    # In a view test case, you can also assert that specific locals are passed
    # to partials:
    #
    #   # assert that the "_customer" partial was rendered with a specific object
    #   assert_template :partial => '_customer', :locals => { :customer => @customer }
    #
    def assert_template(options = {}, message = nil)
      validate_request!

      case options
      when NilClass, String, Symbol
        options = options.to_s if Symbol === options
        rendered = @templates
        msg = build_message(message,
                "expecting <?> but rendering with <?>",
                options, rendered.keys.join(', '))
        assert_block(msg) do
          if options.nil?
            @templates.blank?
          else
            rendered.any? { |t,num| t.match(options) }
          end
        end
      when Hash
        if expected_partial = options[:partial]
          if expected_locals = options[:locals]
            actual_locals = @locals[expected_partial.to_s.sub(/^_/,'')]
            expected_locals.each_pair do |k,v|
              assert_equal(v, actual_locals[k])
            end
          elsif expected_count = options[:count]
            actual_count = @partials[expected_partial]
            msg = build_message(message,
                    "expecting ? to be rendered ? time(s) but rendered ? time(s)",
                     expected_partial, expected_count, actual_count)
            assert(actual_count == expected_count.to_i, msg)
          elsif options.key?(:layout)
            msg = build_message(message,
                    "expecting layout <?> but action rendered <?>",
                    expected_layout, @layouts.keys)

            case layout = options[:layout]
            when String
              assert(@layouts.include?(expected_layout), msg)
            when Regexp
              assert(@layouts.any? {|l| l =~ layout }, msg)
            when nil
              assert(@layouts.empty?, msg)
            end
          else
            msg = build_message(message,
                    "expecting partial <?> but action rendered <?>",
                    options[:partial], @partials.keys)
            assert(@partials.include?(expected_partial), msg)
          end
        else
          assert @partials.empty?,
            "Expected no partials to be rendered"
        end
      end
    end
  end

  class TestRequest < ActionDispatch::TestRequest #:nodoc:
    def initialize(env = {})
      super

      self.session = TestSession.new
      self.session_options = TestSession::DEFAULT_OPTIONS.merge(:id => SecureRandom.hex(16))
    end

    class Result < ::Array #:nodoc:
      def to_s() join '/' end
      def self.new_escaped(strings)
        new strings.collect {|str| uri_parser.unescape str}
      end
    end

    def assign_parameters(routes, controller_path, action, parameters = {})
      parameters = parameters.symbolize_keys.merge(:controller => controller_path, :action => action)
      extra_keys = routes.extra_keys(parameters)
      non_path_parameters = get? ? query_parameters : request_parameters
      parameters.each do |key, value|
        if value.is_a?(Array) && (value.frozen? || value.any?(&:frozen?))
          value = value.map{ |v| v.duplicable? ? v.dup : v }
        elsif value.is_a?(Hash) && (value.frozen? || value.any?{ |k,v| v.frozen? })
          value = Hash[value.map{ |k,v| [k, v.duplicable? ? v.dup : v] }]
        elsif value.frozen? && value.duplicable?
          value = value.dup
        end

        if extra_keys.include?(key.to_sym)
          non_path_parameters[key] = value
        else
          if value.is_a?(Array)
            value = Result.new(value.map(&:to_param))
          else
            value = value.to_param
          end

          path_parameters[key.to_s] = value
        end
      end

      # Clear the combined params hash in case it was already referenced.
      @env.delete("action_dispatch.request.parameters")

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
      write_cookies!
      @env.delete('HTTP_COOKIE') if @cookies.blank?
      @env.delete('action_dispatch.cookies')
      @cookies = nil
      @formats = nil
      @env.delete_if { |k, v| k =~ /^(action_dispatch|rack)\.request/ }
      @env.delete_if { |k, v| k =~ /^action_dispatch\.rescue/ }
      @symbolized_path_params = nil
      @method = @request_method = nil
      @fullpath = @ip = @remote_ip = @protocol = nil
      @env['action_dispatch.request.query_parameters'] = {}
    end
  end

  class TestResponse < ActionDispatch::TestResponse
    def recycle!
      @status = 200
      @header = {}
      @writer = lambda { |x| @body << x }
      @block = nil
      @length = 0
      @body = []
      @charset = @content_type = nil
      @request = @template = nil
    end
  end

  class TestSession < Rack::Session::Abstract::SessionHash #:nodoc:
    DEFAULT_OPTIONS = Rack::Session::Abstract::ID::DEFAULT_OPTIONS

    def initialize(session = {})
      @env, @by = nil, nil
      replace(session.stringify_keys)
      @loaded = true
    end

    def exists?
      true
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
  # 1. First, one uses the +get+, +post+, +put+, +delete+ or +head+ method to simulate
  #    an HTTP request.
  # 2. Then, one asserts whether the current state is as expected. "State" can be anything:
  #    the controller's HTTP response, the database contents, etc.
  #
  # For example:
  #
  #   class BooksControllerTest < ActionController::TestCase
  #     def test_create
  #       # Simulate a POST response with the given HTTP parameters.
  #       post(:create, :book => { :title => "Love Hina" })
  #
  #       # Assert that the controller tried to redirect us to
  #       # the created book's URI.
  #       assert_response :found
  #
  #       # Assert that the controller really put the book in the database.
  #       assert_not_nil Book.find_by_title("Love Hina")
  #     end
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
  # * assigns: Instance variables assigned in the action that are available for the view.
  # * session: Objects being saved in the session.
  # * flash: The flash objects currently in the session.
  # * cookies: \Cookies being sent to the user on this request.
  #
  # These collections can be used just like any other hash:
  #
  #   assert_not_nil assigns(:person) # makes sure that a @person instance variable was set
  #   assert_equal "Dave", cookies[:name] # makes sure that a cookie called :name was set as "Dave"
  #   assert flash.empty? # makes sure that there's nothing in the flash
  #
  # For historic reasons, the assigns hash uses string-based keys. So assigns[:person] won't work, but assigns["person"] will. To
  # appease our yearning for symbols, though, an alternative accessor has been devised using a method call instead of index referencing.
  # So assigns(:person) will work just like assigns["person"], but again, assigns[:person] will not work.
  #
  # On top of the collections, you have the complete url that a given action redirected to available in redirect_to_url.
  #
  # For redirects within the same controller, you can even call follow_redirect and the redirect will be followed, triggering another
  # action call which can then be asserted against.
  #
  # == Manipulating the request collections
  #
  # The collections described above link to the response, so you can test if what the actions were expected to do happened. But
  # sometimes you also want to manipulate these collections in the incoming request. This is really only relevant for sessions
  # and cookies, though. For sessions, you just do:
  #
  #   @request.session[:key] = "value"
  #   @request.cookies[:key] = "value"
  #
  # To clear the cookies for a test just clear the request's cookies hash:
  #
  #   @request.cookies.clear
  #
  # == \Testing named routes
  #
  # If you're using named routes, they can be easily tested using the original named routes' methods straight in the test case.
  # Example:
  #
  #  assert_redirected_to page_url(:title => 'foo')
  class TestCase < ActiveSupport::TestCase
    module Behavior
      extend ActiveSupport::Concern
      include ActionDispatch::TestProcess

      attr_reader :response, :request

      module ClassMethods

        # Sets the controller class name. Useful if the name can't be inferred from test class.
        # Expects +controller_class+ as a constant. Example: <tt>tests WidgetController</tt>.
        def tests(controller_class)
          self.controller_class = controller_class
        end

        def controller_class=(new_class)
          prepare_controller_class(new_class) if new_class
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
          name.sub(/Test$/, '').constantize
        rescue NameError
          nil
        end

        def prepare_controller_class(new_class)
          new_class.send :include, ActionController::TestCase::RaiseActionExceptions
        end

      end

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

      def xml_http_request(request_method, action, parameters = nil, session = nil, flash = nil)
        @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
        @request.env['HTTP_ACCEPT'] ||=  [Mime::JS, Mime::HTML, Mime::XML, 'text/xml', Mime::ALL].join(', ')
        __send__(request_method, action, parameters, session, flash).tap do
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
        when Rack::Test::UploadedFile
          hash_or_array_or_value
        else
          hash_or_array_or_value.to_param
        end
      end

      def process(action, parameters = nil, session = nil, flash = nil, http_method = 'GET')
        # Ensure that numbers and symbols passed as params are converted to
        # proper params, as is the case when engaging rack.
        parameters = paramify_values(parameters) if html_format?(parameters)

        # Sanity check for required instance variables so we can give an
        # understandable error message.
        %w(@routes @controller @request @response).each do |iv_name|
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
        controller_class_name = @controller.class.anonymous? ?
          "anonymous_controller" :
          @controller.class.name.underscore.sub(/_controller$/, '')

        @request.assign_parameters(@routes, controller_class_name, action.to_s, parameters)

        @request.session = ActionController::TestSession.new(session) if session
        @request.session["flash"] = @request.flash.update(flash || {})
        @request.session["flash"].sweep

        @controller.request = @request
        build_request_uri(action, parameters)
        @controller.class.class_eval { include Testing }
        @controller.recycle!
        @controller.process_with_new_base_test(@request, @response)
        @assigns = @controller.respond_to?(:view_assigns) ? @controller.view_assigns : {}
        @request.session.delete('flash') if @request.session['flash'].blank?
        @request.cookies.merge!(@response.cookies)
        @response
      end

      def setup_controller_request_and_response
        @request = TestRequest.new
        @response = TestResponse.new

        if klass = self.class.controller_class
          @controller ||= klass.new rescue nil
        end

        @request.env.delete('PATH_INFO')

        if defined?(@controller) && @controller
          @controller.request = @request
          @controller.params = {}
        end
      end

      # Cause the action to be rescued according to the regular rules for rescue_action when the visitor is not local
      def rescue_action_in_public!
        @request.remote_addr = '208.77.188.166' # example.com
      end

      included do
        include ActionController::TemplateAssertions
        include ActionDispatch::Assertions
        class_attribute :_controller_class
        setup :setup_controller_request_and_response
      end

    private

      def build_request_uri(action, parameters)
        unless @request.env["PATH_INFO"]
          options = @controller.respond_to?(:url_options) ? @controller.__send__(:url_options).merge(parameters) : parameters
          options.update(
            :only_path => true,
            :action => action,
            :relative_url_root => nil,
            :_path_segments => @request.symbolized_path_parameters)

          url, query_string = @routes.url_for(options).split("?", 2)

          @request.env["SCRIPT_NAME"] = @controller.config.relative_url_root
          @request.env["PATH_INFO"] = url
          @request.env["QUERY_STRING"] = query_string || ""
        end
      end

      def html_format?(parameters)
        return true unless parameters.is_a?(Hash)
        format = Mime[parameters[:format]]
        format.nil? || format.html?
      end
    end

    # When the request.remote_addr remains the default for testing, which is 0.0.0.0, the exception is simply raised inline
    # (skipping the regular exception handling from rescue_action). If the request.remote_addr is anything else, the regular
    # rescue_action process takes place. This means you can test your rescue_action code by setting remote_addr to something else
    # than 0.0.0.0.
    #
    # The exception is stored in the exception accessor for further inspection.
    module RaiseActionExceptions
      def self.included(base)
        unless base.method_defined?(:exception) && base.method_defined?(:exception=)
          base.class_eval do
            attr_accessor :exception
            protected :exception, :exception=
          end
        end
      end

      protected
        def rescue_action_without_handler(e)
          self.exception = e

          if request.remote_addr == "0.0.0.0"
            raise(e)
          else
            super(e)
          end
        end
    end

    include Behavior
  end
end
