require 'stringio'
require 'uri'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/object/try'
require 'rack/test'

module ActionDispatch
  module Testing #:nodoc:
    # An instance of this class represents a set of requests and responses
    # performed sequentially by a test process. Because you can instantiate
    # multiple sessions and run them side-by-side, you can also mimic (to some
    # limited extent) multiple simultaneous users interacting with your system.
    #
    # Typically, you will instantiate a new session using
    # TestCase#open_session, rather than instantiating
    # Testing::Session directly.
    class Session
      DEFAULT_HOST = "www.example.com"

      include MiniTest::Assertions
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

        # If the app is a Rails app, make url_helpers available on the session
        # This makes app.url_for and app.foo_path available in the console
        if app.respond_to?(:routes)
          singleton_class.class_eval do
            include app.routes.url_helpers if app.routes.respond_to?(:url_helpers)
            include app.routes.mounted_helpers if app.routes.respond_to?(:mounted_helpers)
          end
        end

        reset!
      end

      def url_options
        @url_options ||= default_url_options.dup.tap do |url_options|
          url_options.reverse_merge!(controller.url_options) if controller

          if @app.respond_to?(:routes) && @app.routes.respond_to?(:default_url_options)
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

      # Return +true+ if the session is mimicking a secure HTTPS request.
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

        # Performs the actual request.
        def process(method, path, parameters = nil, rack_env = nil)
          rack_env ||= {}
          if path =~ %r{://}
            location = URI.parse(path)
            https! URI::HTTPS === location if location.scheme
            host! location.host if location.host
            path = location.query ? "#{location.path}?#{location.query}" : location.path
          end

          unless ActionController::Base < ActionController::Testing
            ActionController::Base.class_eval do
              include ActionController::Testing
            end
          end

          hostname, port = host.split(':')

          env = {
            :method => method,
            :params => parameters,

            "SERVER_NAME"     => hostname,
            "SERVER_PORT"     => port || (https? ? "443" : "80"),
            "HTTPS"           => https? ? "on" : "off",
            "rack.url_scheme" => https? ? "https" : "http",

            "REQUEST_URI"    => path,
            "HTTP_HOST"      => host,
            "REMOTE_ADDR"    => remote_addr,
            "CONTENT_TYPE"   => "application/x-www-form-urlencoded",
            "HTTP_ACCEPT"    => accept
          }

          session = Rack::Test::Session.new(_mock_session)

          env.merge!(rack_env)

          # NOTE: rack-test v0.5 doesn't build a default uri correctly
          # Make sure requested path is always a full uri
          uri = URI.parse('/')
          uri.scheme ||= env['rack.url_scheme']
          uri.host   ||= env['SERVER_NAME']
          uri.port   ||= env['SERVER_PORT'].try(:to_i)
          uri += path

          session.request(uri.to_s, env)

          @request_count += 1
          @request  = ActionDispatch::Request.new(session.last_request.env)
          response = _mock_session.last_response
          @response = ActionDispatch::TestResponse.new(response.status, response.headers, response.body)
          @html_document = nil
          @url_options = nil

          @controller = session.last_request.env['action_controller.instance']

          return response.status
        end
    end
  end
end