require "stringio"
require "uri"
require "active_support/core_ext/kernel/singleton_class"
require "active_support/core_ext/object/try"
require "rack/test"
require "minitest"

module ActionDispatch
  module Integration #:nodoc:
    module RequestHelpers
      # Performs a GET request with the given parameters. See +#process+ for more
      # details.
      def get(path, **args)
        process(:get, path, **args)
      end

      # Performs a POST request with the given parameters. See +#process+ for more
      # details.
      def post(path, **args)
        process(:post, path, **args)
      end

      # Performs a PATCH request with the given parameters. See +#process+ for more
      # details.
      def patch(path, **args)
        process(:patch, path, **args)
      end

      # Performs a PUT request with the given parameters. See +#process+ for more
      # details.
      def put(path, **args)
        process(:put, path, **args)
      end

      # Performs a DELETE request with the given parameters. See +#process+ for
      # more details.
      def delete(path, **args)
        process(:delete, path, **args)
      end

      # Performs a HEAD request with the given parameters. See +#process+ for more
      # details.
      def head(path, *args)
        process(:head, path, *args)
      end

      # Follow a single redirect response. If the last response was not a
      # redirect, an exception will be raised. Otherwise, the redirect is
      # performed on the location header.
      def follow_redirect!
        raise "not a redirect! #{status} #{status_message}" unless redirect?
        get(response.location)
        status
      end
    end

    # An instance of this class represents a set of requests and responses
    # performed sequentially by a test process. Because you can instantiate
    # multiple sessions and run them side-by-side, you can also mimic (to some
    # limited extent) multiple simultaneous users interacting with your system.
    #
    # Typically, you will instantiate a new session using
    # IntegrationTestCase#open_session, rather than instantiating
    # Integration::Session directly.
    class Session
      DEFAULT_HOST = "www.example.com"

      include Minitest::Assertions
      include TestProcess, RequestHelpers, Assertions

      %w( status status_message headers body redirect? ).each do |method|
        delegate method, to: :response, allow_nil: true
      end

      %w( path ).each do |method|
        delegate method, to: :request, allow_nil: true
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

          url_options.reverse_merge!(host: host, protocol: https? ? "https" : "http")
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
        self.accept      = "text/xml,application/xml,application/xhtml+xml," \
                           "text/html;q=0.9,text/plain;q=0.8,image/png," \
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

      # Performs the actual request.
      #
      # - +method+: The HTTP method (GET, POST, PATCH, PUT, DELETE, HEAD, OPTIONS)
      #   as a symbol.
      # - +path+: The URI (as a String) on which you want to perform the
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
      # This method is rarely used directly. Use +#get+, +#post+, or other standard
      # HTTP methods in integration tests. +#process+ is only required when using a
      # request method that doesn't have a method defined in the integration tests.
      #
      # This method returns the response status, after performing the request.
      # Furthermore, if this method was called from an ActionDispatch::IntegrationTestCase object,
      # then that object's <tt>@response</tt> instance variable will point to a Response object
      # which one can use to inspect the details of the response.
      #
      # Example:
      #   process :get, '/author', params: { since: 201501011400 }
      def process(method, path, params: nil, headers: nil, env: nil, xhr: false, as: nil)
        request_encoder = RequestEncoder.encoder(as)
        headers ||= {}

        if method == :get && as == :json && params
          headers["X-Http-Method-Override"] = "GET"
          method = :post
        end

        if path =~ %r{://}
          path = build_expanded_path(path) do |location|
            https! URI::HTTPS === location if location.scheme

            if url_host = location.host
              default = Rack::Request::DEFAULT_PORTS[location.scheme]
              url_host += ":#{location.port}" if default != location.port
              host! url_host
            end
          end
        end

        hostname, port = host.split(":")

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
          "HTTP_ACCEPT"    => request_encoder.accept_header || accept
        }

        wrapped_headers = Http::Headers.from_hash({})
        wrapped_headers.merge!(headers) if headers

        if xhr
          wrapped_headers["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest"
          wrapped_headers["HTTP_ACCEPT"] ||= [Mime[:js], Mime[:html], Mime[:xml], "text/xml", "*/*"].join(", ")
        end

        # This modifies the passed request_env directly.
        if wrapped_headers.present?
          Http::Headers.from_hash(request_env).merge!(wrapped_headers)
        end
        if env.present?
          Http::Headers.from_hash(request_env).merge!(env)
        end

        session = Rack::Test::Session.new(_mock_session)

        # NOTE: rack-test v0.5 doesn't build a default uri correctly
        # Make sure requested path is always a full URI.
        session.request(build_full_uri(path, request_env), request_env)

        @request_count += 1
        @request = ActionDispatch::Request.new(session.last_request.env)
        response = _mock_session.last_response
        @response = ActionDispatch::TestResponse.from_response(response)
        @response.request = @request
        @html_document = nil
        @url_options = nil

        @controller = @request.controller_instance

        response.status
      end

      # Set the host name to use in the next request.
      #
      #   session.host! "www.example.com"
      alias :host! :host=

      private
        def _mock_session
          @_mock_session ||= Rack::MockSession.new(@app, host)
        end

        def build_full_uri(path, env)
          "#{env['rack.url_scheme']}://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{path}"
        end

        def build_expanded_path(path)
          location = URI.parse(path)
          yield location if block_given?
          path = location.path
          location.query ? "#{path}?#{location.query}" : path
        end
    end

    module Runner
      include ActionDispatch::Assertions

      APP_SESSIONS = {}

      attr_reader :app

      def initialize(*args, &blk)
        super(*args, &blk)
        @integration_session = nil
      end

      def before_setup # :nodoc:
        @app = nil
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
          # If the app is a Rails app, make url_helpers available on the session.
          # This makes app.url_for and app.foo_path available in the console.
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
          unless method == "cookies" || method == "assigns"
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
          session.reset!
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

    private
      def respond_to_missing?(method, _)
        integration_session.respond_to?(method) || super
      end

      # Delegate unhandled messages to the current session instance.
      def method_missing(method, *args, &block)
        if integration_session.respond_to?(method)
          integration_session.public_send(method, *args, &block).tap do
            copy_session_variables!
          end
        else
          super
        end
      end
    end
  end
end
