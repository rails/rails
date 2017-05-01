require "action_dispatch/integration_testing/session"

module ActionDispatch
  module IntegrationTesting
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
        klass = APP_SESSIONS[app] ||= Class.new(IntegrationTesting::Session) {
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
