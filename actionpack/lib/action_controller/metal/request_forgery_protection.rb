require 'rack/session/abstract/id'
require 'action_controller/metal/exceptions'

module ActionController #:nodoc:
  class InvalidAuthenticityToken < ActionControllerError #:nodoc:
  end

  class InvalidCrossOriginRequest < ActionControllerError #:nodoc:
  end

  # Controller actions are protected from Cross-Site Request Forgery (CSRF) attacks
  # by including a token in the rendered html for your application. This token is
  # stored as a random string in the session, to which an attacker does not have
  # access. When a request reaches your application, \Rails verifies the received
  # token with the token in the session. Only HTML and JavaScript requests are checked,
  # so this will not protect your XML API (presumably you'll have a different
  # authentication scheme there anyway).
  #
  # GET requests are not protected since they don't have side effects like writing
  # to the database and don't leak sensitive information. JavaScript requests are
  # an exception: a third-party site can use a <script> tag to reference a JavaScript
  # URL on your site. When your JavaScript response loads on their site, it executes.
  # With carefully crafted JavaScript on their end, sensitive data in your JavaScript
  # response may be extracted. To prevent this, only XmlHttpRequest (known as XHR or
  # Ajax) requests are allowed to make GET requests for JavaScript responses.
  #
  # It's important to remember that XML or JSON requests are also affected and if
  # you're building an API you'll need something like:
  #
  #   class ApplicationController < ActionController::Base
  #     protect_from_forgery
  #     skip_before_action :verify_authenticity_token, if: :json_request?
  #
  #     protected
  #
  #     def json_request?
  #       request.format.json?
  #     end
  #   end
  #
  # CSRF protection is turned on with the <tt>protect_from_forgery</tt> method,
  # which checks the token and resets the session if it doesn't match what was expected.
  # A call to this method is generated for new \Rails applications by default.
  #
  # The token parameter is named <tt>authenticity_token</tt> by default. The name and
  # value of this token must be added to every layout that renders forms by including
  # <tt>csrf_meta_tags</tt> in the html +head+.
  #
  # Learn more about CSRF attacks and securing your application in the
  # {Ruby on Rails Security Guide}[http://guides.rubyonrails.org/security.html].
  module RequestForgeryProtection
    extend ActiveSupport::Concern

    include AbstractController::Helpers
    include AbstractController::Callbacks

    included do
      # Sets the token parameter name for RequestForgery. Calling +protect_from_forgery+
      # sets it to <tt>:authenticity_token</tt> by default.
      config_accessor :request_forgery_protection_token
      self.request_forgery_protection_token ||= :authenticity_token

      # Holds the class which implements the request forgery protection.
      config_accessor :forgery_protection_strategy
      self.forgery_protection_strategy = nil

      # Controls whether request forgery protection is turned on or not. Turned off by default only in test mode.
      config_accessor :allow_forgery_protection
      self.allow_forgery_protection = true if allow_forgery_protection.nil?

      helper_method :form_authenticity_token
      helper_method :protect_against_forgery?
    end

    module ClassMethods
      # Turn on request forgery protection. Bear in mind that only non-GET, HTML/JavaScript requests are checked.
      #
      #   class ApplicationController < ActionController::Base
      #     protect_from_forgery
      #   end
      #
      #   class FooController < ApplicationController
      #     protect_from_forgery except: :index
      #
      # You can disable CSRF protection on controller by skipping the verification before_action:
      #   skip_before_action :verify_authenticity_token
      #
      # Valid Options:
      #
      # * <tt>:only/:except</tt> - Passed to the <tt>before_action</tt> call. Set which actions are verified.
      # * <tt>:with</tt> - Set the method to handle unverified request.
      #
      # Valid unverified request handling methods are:
      # * <tt>:exception</tt> - Raises ActionController::InvalidAuthenticityToken exception.
      # * <tt>:reset_session</tt> - Resets the session.
      # * <tt>:null_session</tt> - Provides an empty session during request but doesn't reset it completely. Used as default if <tt>:with</tt> option is not specified.
      def protect_from_forgery(options = {})
        self.forgery_protection_strategy = protection_method_class(options[:with] || :null_session)
        self.request_forgery_protection_token ||= :authenticity_token
        prepend_before_action :verify_authenticity_token, options
        append_after_action :verify_same_origin_request
      end

      private

      def protection_method_class(name)
        ActionController::RequestForgeryProtection::ProtectionMethods.const_get(name.to_s.classify)
      rescue NameError
        raise ArgumentError, 'Invalid request forgery protection method, use :null_session, :exception, or :reset_session'
      end
    end

    module ProtectionMethods
      class NullSession
        def initialize(controller)
          @controller = controller
        end

        # This is the method that defines the application behavior when a request is found to be unverified.
        def handle_unverified_request
          request = @controller.request
          request.session = NullSessionHash.new(request.env)
          request.env['action_dispatch.request.flash_hash'] = nil
          request.env['rack.session.options'] = { skip: true }
          request.env['action_dispatch.cookies'] = NullCookieJar.build(request)
        end

        protected

        class NullSessionHash < Rack::Session::Abstract::SessionHash #:nodoc:
          def initialize(env)
            super(nil, env)
            @data = {}
            @loaded = true
          end

          # no-op
          def destroy; end

          def exists?
            true
          end
        end

        class NullCookieJar < ActionDispatch::Cookies::CookieJar #:nodoc:
          def self.build(request)
            key_generator = request.env[ActionDispatch::Cookies::GENERATOR_KEY]
            host          = request.host
            secure        = request.ssl?

            new(key_generator, host, secure, options_for_env({}))
          end

          def write(*)
            # nothing
          end
        end
      end

      class ResetSession
        def initialize(controller)
          @controller = controller
        end

        def handle_unverified_request
          @controller.reset_session
        end
      end

      class Exception
        def initialize(controller)
          @controller = controller
        end

        def handle_unverified_request
          raise ActionController::InvalidAuthenticityToken
        end
      end
    end

    protected
      # The actual before_action that is used to verify the CSRF token.
      # Don't override this directly. Provide your own forgery protection
      # strategy instead. If you override, you'll disable same-origin
      # `<script>` verification.
      #
      # Lean on the protect_from_forgery declaration to mark which actions are
      # due for same-origin request verification. If protect_from_forgery is
      # enabled on an action, this before_action flags its after_action to
      # verify that JavaScript responses are for XHR requests, ensuring they
      # follow the browser's same-origin policy.
      def verify_authenticity_token
        mark_for_same_origin_verification!

        if !verified_request?
          logger.warn "Can't verify CSRF token authenticity" if logger
          handle_unverified_request
        end
      end

      def handle_unverified_request
        forgery_protection_strategy.new(self).handle_unverified_request
      end

      CROSS_ORIGIN_JAVASCRIPT_WARNING = "Security warning: an embedded " \
        "<script> tag on another site requested protected JavaScript. " \
        "If you know what you're doing, go ahead and disable forgery " \
        "protection on this action to permit cross-origin JavaScript embedding."
      private_constant :CROSS_ORIGIN_JAVASCRIPT_WARNING

      # If `verify_authenticity_token` was run (indicating that we have
      # forgery protection enabled for this request) then also verify that
      # we aren't serving an unauthorized cross-origin response.
      def verify_same_origin_request
        if marked_for_same_origin_verification? && non_xhr_javascript_response?
          logger.warn CROSS_ORIGIN_JAVASCRIPT_WARNING if logger
          raise ActionController::InvalidCrossOriginRequest, CROSS_ORIGIN_JAVASCRIPT_WARNING
        end
      end

      # GET requests are checked for cross-origin JavaScript after rendering.
      def mark_for_same_origin_verification!
        @marked_for_same_origin_verification = request.get?
      end

      # If the `verify_authenticity_token` before_action ran, verify that
      # JavaScript responses are only served to same-origin GET requests.
      def marked_for_same_origin_verification?
        @marked_for_same_origin_verification ||= false
      end

      # Check for cross-origin JavaScript responses.
      def non_xhr_javascript_response?
        content_type =~ %r(\Atext/javascript) && !request.xhr?
      end

      # Returns true or false if a request is verified. Checks:
      #
      # * is it a GET or HEAD request?  Gets should be safe and idempotent
      # * Does the form_authenticity_token match the given token value from the params?
      # * Does the X-CSRF-Token header match the form_authenticity_token
      def verified_request?
        !protect_against_forgery? || request.get? || request.head? ||
          form_authenticity_token == params[request_forgery_protection_token] ||
          form_authenticity_token == request.headers['X-CSRF-Token']
      end

      # Sets the token value for the current session.
      def form_authenticity_token
        session[:_csrf_token] ||= SecureRandom.base64(32)
      end

      # The form's authenticity parameter. Override to provide your own.
      def form_authenticity_param
        params[request_forgery_protection_token]
      end

      # Checks if the controller allows forgery protection.
      def protect_against_forgery?
        allow_forgery_protection
      end
  end
end
