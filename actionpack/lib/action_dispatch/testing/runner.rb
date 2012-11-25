require 'stringio'
require 'uri'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/object/try'
require 'rack/test'

module ActionDispatch
  module Testing #:nodoc:
    module Runner
      include ActionDispatch::Assertions

      def app
        @app ||= nil
      end

      # Reset the current session. This is useful for testing multiple sessions
      # in a single test case.
      def reset!
        @integration_session = Testing::Session.new(app)
      end

      %w(get post patch put head delete options cookies assigns
         xml_http_request xhr get_via_redirect post_via_redirect).each do |method|
        define_method(method) do |*args|
          reset! unless integration_session
          # reset the html_document variable, but only for new get/post calls
          @html_document = nil unless method == 'cookies' || method == 'assigns'
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
      def open_session(app = nil)
        dup.tap do |session|
          yield session if block_given?
        end
      end

      # Copy the instance variables from the current session instance into the
      # test instance.
      def copy_session_variables! #:nodoc:
        return unless integration_session
        %w(controller response request).each do |var|
          instance_variable_set("@#{var}", @integration_session.__send__(var))
        end
      end

      def default_url_options
        reset! unless integration_session
        integration_session.default_url_options
      end

      def default_url_options=(options)
        reset! unless integration_session
        integration_session.default_url_options = options
      end

      def respond_to?(method, include_private = false)
        integration_session.respond_to?(method, include_private) || super
      end

      # Delegate unhandled messages to the current session instance.
      def method_missing(sym, *args, &block)
        reset! unless integration_session
        if integration_session.respond_to?(sym)
          integration_session.__send__(sym, *args, &block).tap do
            copy_session_variables!
          end
        else
          super
        end
      end

      private
        def integration_session
          @integration_session ||= nil
        end
    end
  end
end
