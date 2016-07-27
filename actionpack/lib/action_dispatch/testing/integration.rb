require 'stringio'
require 'uri'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/string/strip'
require 'rack/test'
require 'minitest'

require 'action_dispatch/testing/request_encoder'

module ActionDispatch
  module Integration #:nodoc:
    module RequestHelpers
      # Performs a GET request with the given parameters.
      #
      # - +path+: The URI (as a String) on which you want to perform a GET
      #   request.
      # - +params+: The HTTP parameters that you want to pass. This may
      #   be +nil+,
      #   a Hash, or a String that is appropriately encoded
      #   (<tt>application/x-www-form-urlencoded</tt> or
      #   <tt>multipart/form-data</tt>).
      # - +headers+: Additional headers to pass, as a Hash. The headers will be
      #   merged into the Rack env hash.
      # - +env+: Additional env to pass, as a Hash. The headers will be
      #   merged into the Rack env hash.
      #
      # This method returns a Response object, which one can use to
      # inspect the details of the response. Furthermore, if this method was
      # called from an ActionDispatch::IntegrationTest object, then that
      # object's <tt>@response</tt> instance variable will point to the same
      # response object.
      #
      # You can also perform POST, PATCH, PUT, DELETE, and HEAD requests with
      # +#post+, +#patch+, +#put+, +#delete+, and +#head+.
      #
      # Example:
      #
      #   get '/feed', params: { since: 201501011400 }
      #   post '/profile', headers: { "X-Test-Header" => "testvalue" }
      def get(path, *args)
        process_with_kwargs(:get, path, *args)
      end

      # Performs a POST request with the given parameters. See +#get+ for more
      # details.
      def post(path, *args)
        process_with_kwargs(:post, path, *args)
      end

      # Performs a PATCH request with the given parameters. See +#get+ for more
      # details.
      def patch(path, *args)
        process_with_kwargs(:patch, path, *args)
      end

      # Performs a PUT request with the given parameters. See +#get+ for more
      # details.
      def put(path, *args)
        process_with_kwargs(:put, path, *args)
      end

      # Performs a DELETE request with the given parameters. See +#get+ for
      # more details.
      def delete(path, *args)
        process_with_kwargs(:delete, path, *args)
      end

      # Performs a HEAD request with the given parameters. See +#get+ for more
      # details.
      def head(path, *args)
        process_with_kwargs(:head, path, *args)
      end

      # Performs an XMLHttpRequest request with the given parameters, mirroring
      # an AJAX request made from JavaScript.
      #
      # The request_method is +:get+, +:post+, +:patch+, +:put+, +:delete+ or
      # +:head+; the parameters are +nil+, a hash, or a url-encoded or multipart
      # string; the headers are a hash.
      #
      # Example:
      #
      #   xhr :get, '/feed', params: { since: 201501011400 }
      def xml_http_request(request_method, path, *args)
        if kwarg_request?(args)
          params, headers, env = args.first.values_at(:params, :headers, :env)
        else
          params = args[0]
          headers = args[1]
          env = {}

          if params.present? || headers.present?
            non_kwarg_request_warning
          end
        end

        ActiveSupport::Deprecation.warn(<<-MSG.strip_heredoc)
          xhr and xml_http_request methods are deprecated in favor of
          `get "/posts", xhr: true` and `post "/posts/1", xhr: true`.
        MSG

        process(request_method, path, params: params, headers: headers, xhr: true)
      end
      alias xhr :xml_http_request

      # Follow a single redirect response. If the last response was not a
      # redirect, an exception will be raised. Otherwise, the redirect is
      # performed on the location header.
      def follow_redirect!
        raise "not a redirect! #{status} #{status_message}" unless redirect?
        get(response.location)
        status
      end

      # Performs a request using the specified method, following any subsequent
      # redirect. Note that the redirects are followed until the response is
      # not a redirect--this means you may run into an infinite loop if your
      # redirect loops back to itself.
      #
      # Example:
      #
      #   request_via_redirect :post, '/welcome',
      #     params: { ref_id: 14 },
      #     headers: { "X-Test-Header" => "testvalue" }
      def request_via_redirect(http_method, path, *args)
        ActiveSupport::Deprecation.warn('`request_via_redirect` is deprecated and will be removed in Rails 5.1. Please use `follow_redirect!` manually after the request call for the same behavior.')
        process_with_kwargs(http_method, path, *args)

        follow_redirect! while redirect?
        status
      end

      # Performs a GET request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def get_via_redirect(path, *args)
        ActiveSupport::Deprecation.warn('`get_via_redirect` is deprecated and will be removed in Rails 5.1. Please use `follow_redirect!` manually after the request call for the same behavior.')
        request_via_redirect(:get, path, *args)
      end

      # Performs a POST request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def post_via_redirect(path, *args)
        ActiveSupport::Deprecation.warn('`post_via_redirect` is deprecated and will be removed in Rails 5.1. Please use `follow_redirect!` manually after the request call for the same behavior.')
        request_via_redirect(:post, path, *args)
      end

      # Performs a PATCH request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def patch_via_redirect(path, *args)
        ActiveSupport::Deprecation.warn('`patch_via_redirect` is deprecated and will be removed in Rails 5.1. Please use `follow_redirect!` manually after the request call for the same behavior.')
        request_via_redirect(:patch, path, *args)
      end

      # Performs a PUT request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def put_via_redirect(path, *args)
        ActiveSupport::Deprecation.warn('`put_via_redirect` is deprecated and will be removed in Rails 5.1. Please use `follow_redirect!` manually after the request call for the same behavior.')
        request_via_redirect(:put, path, *args)
      end

      # Performs a DELETE request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def delete_via_redirect(path, *args)
        ActiveSupport::Deprecation.warn('`delete_via_redirect` is deprecated and will be removed in Rails 5.1. Please use `follow_redirect!` manually after the request call for the same behavior.')
        request_via_redirect(:delete, path, *args)
      end
    end

    # An instance of this class represents a set of requests and responses
    # performed sequentially by a test process. Because you can instantiate
    # multiple sessions and run them side-by-side, you can also mimic (to some
    # limited extent) multiple simultaneous users interacting with your system.
    #
    # Typically, you will instantiate a new session using
    # IntegrationTest#open_session, rather than instantiating
    # Integration::Session directly.
    class Session
      DEFAULT_HOST = "www.example.com"

      include Minitest::Assertions
      include TestProcess, RequestHelpers, Assertions

      %w( status status_message headers body redirect? ).each do |method|
        delegate method, :to => :response, :allow_nil => true
      end

      %w( path ).each do |method|
        delegate method, :to => :request, :allow_nil => true
      end

      # The hostname used in the last request.
      def host
        @host || DEFAULT_HOST
      end
      attr_writer :host

      # The remote_addr used in the last request.
      attr_accessor :remote_addr

      # The Accept header to send.
      attr_accessor :accept

      # A map of the cookies returned by the last response, and which will be
      # sent with the next request.
      def cookies
        _mock_session.cookie_jar
      end

      # A reference to the controller instance used by the last request.
      attr_reader :controller

      # A reference to the request instance used by the last request.
      attr_reader :request

      # A reference to the response instance used by the last request.
      attr_reader :response

      # A running counter of the number of requests processed.
      attr_accessor :request_count

      include ActionDispatch::Routing::UrlFor

      # Create and initialize a new Session instance.
      def initialize(app)
        super()
        @app = app

        reset!
      end

      def url_options
        @url_options ||= default_url_options.dup.tap do |url_options|
          url_options.reverse_merge!(controller.url_options) if controller

          if @app.respond_to?(:routes)
            url_options.reverse_merge!(@app.routes.default_url_options)
          end

          url_options.reverse_merge!(:host => host, :protocol => https? ? "https" : "http")
        end
      end

      # Resets the instance. This can be used to reset the state information
      # in an existing session instance, so it can be used from a clean-slate
      # condition.
      #
      #   session.reset!
      def reset!
        @https = false
        @controller = @request = @response = nil
        @_mock_session = nil
        @request_count = 0
        @url_options = nil

        self.host        = DEFAULT_HOST
        self.remote_addr = "127.0.0.1"
        self.accept      = "text/xml,application/xml,application/xhtml+xml," +
                           "text/html;q=0.9,text/plain;q=0.8,image/png," +
                           "*/*;q=0.5"

        unless defined? @named_routes_configured
          # the helpers are made protected by default--we make them public for
          # easier access during testing and troubleshooting.
          @named_routes_configured = true
        end
      end

      # Specify whether or not the session should mimic a secure HTTPS request.
      #
      #   session.https!
      #   session.https!(false)
      def https!(flag = true)
        @https = flag
      end

      # Returns +true+ if the session is mimicking a secure HTTPS request.
      #
      #   if session.https?
      #     ...
      #   end
      def https?
        @https
      end

      # Set the host name to use in the next request.
      #
      #   session.host! "www.example.com"
      alias :host! :host=

      private
        def _mock_session
          @_mock_session ||= Rack::MockSession.new(@app, host)
        end

        def process_with_kwargs(http_method, path, *args)
          if kwarg_request?(args)
            process(http_method, path, *args)
          else
            non_kwarg_request_warning if args.any?
            process(http_method, path, { params: args[0], headers: args[1] })
          end
        end

        REQUEST_KWARGS = %i(params headers env xhr as)
        def kwarg_request?(args)
          args[0].respond_to?(:keys) && args[0].keys.any? { |k| REQUEST_KWARGS.include?(k) }
        end

        def non_kwarg_request_warning
          ActiveSupport::Deprecation.warn(<<-MSG.strip_heredoc)
            ActionDispatch::IntegrationTest HTTP request methods will accept only
            the following keyword arguments in future Rails versions:
            #{REQUEST_KWARGS.join(', ')}

            Examples:

            get '/profile',
              params: { id: 1 },
              headers: { 'X-Extra-Header' => '123' },
              env: { 'action_dispatch.custom' => 'custom' },
              xhr: true,
              as: :json
          MSG
        end

        # Performs the actual request.
        def process(method, path, params: nil, headers: nil, env: nil, xhr: false, as: nil)
          request_encoder = RequestEncoder.encoder(as)

          if path =~ %r{://}
            path = build_expanded_path(path, request_encoder) do |location|
              https! URI::HTTPS === location if location.scheme

              if url_host = location.host
                default = Rack::Request::DEFAULT_PORTS[location.scheme]
                url_host += ":#{location.port}" if default != location.port
                host! url_host
              end
            end
          elsif as
            path = build_expanded_path(path, request_encoder)
          end

          hostname, port = host.split(':')

          request_env = {
            :method => method,
            :params => request_encoder.encode_params(params),

            "SERVER_NAME"     => hostname,
            "SERVER_PORT"     => port || (https? ? "443" : "80"),
            "HTTPS"           => https? ? "on" : "off",
            "rack.url_scheme" => https? ? "https" : "http",

            "REQUEST_URI"    => path,
            "HTTP_HOST"      => host,
            "REMOTE_ADDR"    => remote_addr,
            "CONTENT_TYPE"   => request_encoder.content_type,
            "HTTP_ACCEPT"    => accept
          }

          if xhr
            headers ||= {}
            headers['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
            headers['HTTP_ACCEPT'] ||= [Mime[:js], Mime[:html], Mime[:xml], 'text/xml', '*/*'].join(', ')
          end

          # this modifies the passed request_env directly
          if headers.present?
            Http::Headers.from_hash(request_env).merge!(headers)
          end
          if env.present?
            Http::Headers.from_hash(request_env).merge!(env)
          end

          session = Rack::Test::Session.new(_mock_session)

          # NOTE: rack-test v0.5 doesn't build a default uri correctly
          # Make sure requested path is always a full uri
          session.request(build_full_uri(path, request_env), request_env)

          @request_count += 1
          @request  = ActionDispatch::Request.new(session.last_request.env)
          response = _mock_session.last_response
          @response = ActionDispatch::TestResponse.from_response(response)
          @response.request = @request
          @html_document = nil
          @url_options = nil

          @controller = @request.controller_instance

          response.status
        end

        def build_full_uri(path, env)
          "#{env['rack.url_scheme']}://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{path}"
        end

        def build_expanded_path(path, request_encoder)
          location = URI.parse(path)
          yield location if block_given?
          path = request_encoder.append_format_to location.path
          location.query ? "#{path}?#{location.query}" : path
        end
    end

    module Runner
      include ActionDispatch::Assertions

      APP_SESSIONS = {}

      attr_reader :app

      def before_setup # :nodoc:
        @app = nil
        @integration_session = nil
        super
      end

      def integration_session
        @integration_session ||= create_session(app)
      end

      # Reset the current session. This is useful for testing multiple sessions
      # in a single test case.
      def reset!
        @integration_session = create_session(app)
      end

      def create_session(app)
        klass = APP_SESSIONS[app] ||= Class.new(Integration::Session) {
          # If the app is a Rails app, make url_helpers available on the session
          # This makes app.url_for and app.foo_path available in the console
          if app.respond_to?(:routes)
            include app.routes.url_helpers
            include app.routes.mounted_helpers
          end
        }
        klass.new(app)
      end

      def remove! # :nodoc:
        @integration_session = nil
      end

      %w(get post patch put head delete cookies assigns
         xml_http_request xhr get_via_redirect post_via_redirect).each do |method|
        define_method(method) do |*args|
          # reset the html_document variable, except for cookies/assigns calls
          unless method == 'cookies' || method == 'assigns'
            @html_document = nil
          end

          integration_session.__send__(method, *args).tap do
            copy_session_variables!
          end
        end
      end

      # Open a new session instance. If a block is given, the new session is
      # yielded to the block before being returned.
      #
      #   session = open_session do |sess|
      #     sess.extend(CustomAssertions)
      #   end
      #
      # By default, a single session is automatically created for you, but you
      # can use this method to open multiple sessions that ought to be tested
      # simultaneously.
      def open_session
        dup.tap do |session|
          yield session if block_given?
        end
      end

      # Copy the instance variables from the current session instance into the
      # test instance.
      def copy_session_variables! #:nodoc:
        @controller = @integration_session.controller
        @response   = @integration_session.response
        @request    = @integration_session.request
      end

      def default_url_options
        integration_session.default_url_options
      end

      def default_url_options=(options)
        integration_session.default_url_options = options
      end

      def respond_to?(method, include_private = false)
        integration_session.respond_to?(method, include_private) || super
      end

      # Delegate unhandled messages to the current session instance.
      def method_missing(sym, *args, &block)
        if integration_session.respond_to?(sym)
          integration_session.__send__(sym, *args, &block).tap do
            copy_session_variables!
          end
        else
          super
        end
      end
    end
  end

  # An integration test spans multiple controllers and actions,
  # tying them all together to ensure they work together as expected. It tests
  # more completely than either unit or functional tests do, exercising the
  # entire stack, from the dispatcher to the database.
  #
  # At its simplest, you simply extend <tt>IntegrationTest</tt> and write your tests
  # using the get/post methods:
  #
  #   require "test_helper"
  #
  #   class ExampleTest < ActionDispatch::IntegrationTest
  #     fixtures :people
  #
  #     def test_login
  #       # get the login page
  #       get "/login"
  #       assert_equal 200, status
  #
  #       # post the login and follow through to the home page
  #       post "/login", params: { username: people(:jamis).username,
  #         password: people(:jamis).password }
  #       follow_redirect!
  #       assert_equal 200, status
  #       assert_equal "/home", path
  #     end
  #   end
  #
  # However, you can also have multiple session instances open per test, and
  # even extend those instances with assertions and methods to create a very
  # powerful testing DSL that is specific for your application. You can even
  # reference any named routes you happen to have defined.
  #
  #   require "test_helper"
  #
  #   class AdvancedTest < ActionDispatch::IntegrationTest
  #     fixtures :people, :rooms
  #
  #     def test_login_and_speak
  #       jamis, david = login(:jamis), login(:david)
  #       room = rooms(:office)
  #
  #       jamis.enter(room)
  #       jamis.speak(room, "anybody home?")
  #
  #       david.enter(room)
  #       david.speak(room, "hello!")
  #     end
  #
  #     private
  #
  #       module CustomAssertions
  #         def enter(room)
  #           # reference a named route, for maximum internal consistency!
  #           get(room_url(id: room.id))
  #           assert(...)
  #           ...
  #         end
  #
  #         def speak(room, message)
  #           post "/say/#{room.id}", xhr: true, params: { message: message }
  #           assert(...)
  #           ...
  #         end
  #       end
  #
  #       def login(who)
  #         open_session do |sess|
  #           sess.extend(CustomAssertions)
  #           who = people(who)
  #           sess.post "/login", params: { username: who.username,
  #             password: who.password }
  #           assert(...)
  #         end
  #       end
  #   end
  #
  # Another longer example would be:
  #
  # A simple integration test that exercises multiple controllers:
  #
  #   require 'test_helper'
  #
  #   class UserFlowsTest < ActionDispatch::IntegrationTest
  #     test "login and browse site" do
  #       # login via https
  #       https!
  #       get "/login"
  #       assert_response :success
  #
  #       post "/login", params: { username: users(:david).username, password: users(:david).password }
  #       follow_redirect!
  #       assert_equal '/welcome', path
  #       assert_equal 'Welcome david!', flash[:notice]
  #
  #       https!(false)
  #       get "/articles/all"
  #       assert_response :success
  #       assert_select 'h1', 'Articles'
  #     end
  #   end
  #
  # As you can see the integration test involves multiple controllers and
  # exercises the entire stack from database to dispatcher. In addition you can
  # have multiple session instances open simultaneously in a test and extend
  # those instances with assertion methods to create a very powerful testing
  # DSL (domain-specific language) just for your application.
  #
  # Here's an example of multiple sessions and custom DSL in an integration test
  #
  #   require 'test_helper'
  #
  #   class UserFlowsTest < ActionDispatch::IntegrationTest
  #     test "login and browse site" do
  #       # User david logs in
  #       david = login(:david)
  #       # User guest logs in
  #       guest = login(:guest)
  #
  #       # Both are now available in different sessions
  #       assert_equal 'Welcome david!', david.flash[:notice]
  #       assert_equal 'Welcome guest!', guest.flash[:notice]
  #
  #       # User david can browse site
  #       david.browses_site
  #       # User guest can browse site as well
  #       guest.browses_site
  #
  #       # Continue with other assertions
  #     end
  #
  #     private
  #
  #       module CustomDsl
  #         def browses_site
  #           get "/products/all"
  #           assert_response :success
  #           assert_select 'h1', 'Products'
  #         end
  #       end
  #
  #       def login(user)
  #         open_session do |sess|
  #           sess.extend(CustomDsl)
  #           u = users(user)
  #           sess.https!
  #           sess.post "/login", params: { username: u.username, password: u.password }
  #           assert_equal '/welcome', sess.path
  #           sess.https!(false)
  #         end
  #       end
  #   end
  #
  # You can also test your JSON API easily by setting what the request should
  # be encoded as:
  #
  #   require 'test_helper'
  #
  #   class ApiTest < ActionDispatch::IntegrationTest
  #     test 'creates articles' do
  #       assert_difference -> { Article.count } do
  #         post articles_path, params: { article: { title: 'Ahoy!' } }, as: :json
  #       end
  #
  #       assert_response :success
  #       assert_equal({ id: Arcticle.last.id, title: 'Ahoy!' }, response.parsed_body)
  #     end
  #   end
  #
  # The `as` option sets the format to JSON, sets the content type to
  # 'application/json' and encodes the parameters as JSON.
  #
  # Calling `parsed_body` on the response parses the response body as what
  # the last request was encoded as. If the request wasn't encoded `as` something,
  # it's the same as calling `body`.
  #
  # For any custom MIME Types you've registered, you can even add your own encoders with:
  #
  #   ActionDispatch::IntegrationTest.register_encoder :wibble,
  #     param_encoder: -> params { params.to_wibble },
  #     response_parser: -> body { body }
  #
  # Where `param_encoder` defines how the params should be encoded and
  # `response_parser` defines how the response body should be parsed through
  # `parsed_body`.
  #
  # Consult the Rails Testing Guide for more.

  class IntegrationTest < ActiveSupport::TestCase
    module UrlOptions
      extend ActiveSupport::Concern
      def url_options
        integration_session.url_options
      end
    end

    module Behavior
      extend ActiveSupport::Concern

      include Integration::Runner
      include ActionController::TemplateAssertions

      included do
        include ActionDispatch::Routing::UrlFor
        include UrlOptions # don't let UrlFor override the url_options method
        ActiveSupport.run_load_hooks(:action_dispatch_integration_test, self)
        @@app = nil
      end

      module ClassMethods
        def app
          if defined?(@@app) && @@app
            @@app
          else
            ActionDispatch.test_app
          end
        end

        def app=(app)
          @@app = app
        end

        def register_encoder(*args)
          RequestEncoder.register_encoder(*args)
        end
      end

      def app
        super || self.class.app
      end

      def document_root_element
        html_document.root
      end
    end

    include Behavior
  end
end
