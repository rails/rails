# frozen_string_literal: true

# :markup: markdown

require "rack/session/abstract/id"
require "action_controller/metal/exceptions"
require "active_support/security_utils"

module ActionController # :nodoc:
  class InvalidAuthenticityToken < ActionControllerError # :nodoc:
  end

  class InvalidCrossOriginRequest < ActionControllerError # :nodoc:
  end

  # # Action Controller Request Forgery Protection
  #
  # Controller actions are protected from Cross-Site Request Forgery (CSRF)
  # attacks by including a token in the rendered HTML for your application. This
  # token is stored as a random string in the session, to which an attacker does
  # not have access. When a request reaches your application, Rails verifies the
  # received token with the token in the session. All requests are checked except
  # GET requests as these should be idempotent. Keep in mind that all
  # session-oriented requests are CSRF protected by default, including JavaScript
  # and HTML requests.
  #
  # Since HTML and JavaScript requests are typically made from the browser, we
  # need to ensure to verify request authenticity for the web browser. We can use
  # session-oriented authentication for these types of requests, by using the
  # `protect_from_forgery` method in our controllers.
  #
  # GET requests are not protected since they don't have side effects like writing
  # to the database and don't leak sensitive information. JavaScript requests are
  # an exception: a third-party site can use a <script> tag to reference a
  # JavaScript URL on your site. When your JavaScript response loads on their
  # site, it executes. With carefully crafted JavaScript on their end, sensitive
  # data in your JavaScript response may be extracted. To prevent this, only
  # XmlHttpRequest (known as XHR or Ajax) requests are allowed to make requests
  # for JavaScript responses.
  #
  # Subclasses of ActionController::Base are protected by default with the
  # `:exception` strategy, which raises an
  # ActionController::InvalidAuthenticityToken error on unverified requests.
  #
  # APIs may want to disable this behavior since they are typically designed to be
  # state-less: that is, the request API client handles the session instead of
  # Rails. One way to achieve this is to use the `:null_session` strategy instead,
  # which allows unverified requests to be handled, but with an empty session:
  #
  #     class ApplicationController < ActionController::Base
  #       protect_from_forgery with: :null_session
  #     end
  #
  # Note that API only applications don't include this module or a session
  # middleware by default, and so don't require CSRF protection to be configured.
  #
  # The token parameter is named `authenticity_token` by default. The name and
  # value of this token must be added to every layout that renders forms by
  # including `csrf_meta_tags` in the HTML `head`.
  #
  # Learn more about CSRF attacks and securing your application in the [Ruby on
  # Rails Security Guide](https://guides.rubyonrails.org/security.html).
  module RequestForgeryProtection
    CSRF_TOKEN = "action_controller.csrf_token"

    extend ActiveSupport::Concern

    include AbstractController::Helpers
    include AbstractController::Callbacks

    included do
      # Sets the token parameter name for RequestForgery. Calling
      # `protect_from_forgery` sets it to `:authenticity_token` by default.
      config_accessor :request_forgery_protection_token
      self.request_forgery_protection_token ||= :authenticity_token

      # Holds the class which implements the request forgery protection.
      config_accessor :forgery_protection_strategy
      self.forgery_protection_strategy = nil

      # Controls whether request forgery protection is turned on or not. Turned off by
      # default only in test mode.
      config_accessor :allow_forgery_protection
      self.allow_forgery_protection = true if allow_forgery_protection.nil?

      # Controls whether a CSRF failure logs a warning. On by default.
      config_accessor :log_warning_on_csrf_failure
      self.log_warning_on_csrf_failure = true

      # Controls whether the Origin header is checked in addition to the CSRF token.
      config_accessor :forgery_protection_origin_check
      self.forgery_protection_origin_check = false

      # Controls whether form-action/method specific CSRF tokens are used.
      config_accessor :per_form_csrf_tokens
      self.per_form_csrf_tokens = false

      # The strategy to use for storing and retrieving CSRF tokens.
      config_accessor :csrf_token_storage_strategy
      self.csrf_token_storage_strategy = SessionStore.new

      helper_method :form_authenticity_token
      helper_method :protect_against_forgery?
    end

    module ClassMethods
      # Turn on request forgery protection. Bear in mind that GET and HEAD requests
      # are not checked.
      #
      #     class ApplicationController < ActionController::Base
      #       protect_from_forgery
      #     end
      #
      #     class FooController < ApplicationController
      #       protect_from_forgery except: :index
      #     end
      #
      # You can disable forgery protection on a controller using
      # skip_forgery_protection:
      #
      #     class BarController < ApplicationController
      #       skip_forgery_protection
      #     end
      #
      # Valid Options:
      #
      # *   `:only` / `:except` - Only apply forgery protection to a subset of
      #     actions. For example `only: [ :create, :create_all ]`.
      # *   `:if` / `:unless` - Turn off the forgery protection entirely depending on
      #     the passed Proc or method reference.
      # *   `:prepend` - By default, the verification of the authentication token will
      #     be added at the position of the protect_from_forgery call in your
      #     application. This means any callbacks added before are run first. This is
      #     useful when you want your forgery protection to depend on other callbacks,
      #     like authentication methods (Oauth vs Cookie auth).
      #
      #     If you need to add verification to the beginning of the callback chain,
      #     use `prepend: true`.
      # *   `:with` - Set the method to handle unverified request. Note if
      #     `default_protect_from_forgery` is true, Rails call protect_from_forgery
      #     with `with :exception`.
      #
      #
      # Built-in unverified request handling methods are:
      # *   `:exception` - Raises ActionController::InvalidAuthenticityToken
      #     exception.
      # *   `:reset_session` - Resets the session.
      # *   `:null_session` - Provides an empty session during request but doesn't
      #     reset it completely. Used as default if `:with` option is not specified.
      #
      #
      # You can also implement custom strategy classes for unverified request
      # handling:
      #
      #     class CustomStrategy
      #       def initialize(controller)
      #         @controller = controller
      #       end
      #
      #       def handle_unverified_request
      #         # Custom behavior for unverfied request
      #       end
      #     end
      #
      #     class ApplicationController < ActionController::Base
      #       protect_from_forgery with: CustomStrategy
      #     end
      #
      # *   `:store` - Set the strategy to store and retrieve CSRF tokens.
      #
      #
      # Built-in session token strategies are:
      # *   `:session` - Store the CSRF token in the session.  Used as default if
      #     `:store` option is not specified.
      # *   `:cookie` - Store the CSRF token in an encrypted cookie.
      #
      #
      # You can also implement custom strategy classes for CSRF token storage:
      #
      #     class CustomStore
      #       def fetch(request)
      #         # Return the token from a custom location
      #       end
      #
      #       def store(request, csrf_token)
      #         # Store the token in a custom location
      #       end
      #
      #       def reset(request)
      #         # Delete the stored session token
      #       end
      #     end
      #
      #     class ApplicationController < ActionController::Base
      #       protect_from_forgery store: CustomStore.new
      #     end
      def protect_from_forgery(options = {})
        options = options.reverse_merge(prepend: false)

        self.forgery_protection_strategy = protection_method_class(options[:with] || :null_session)
        self.request_forgery_protection_token ||= :authenticity_token

        self.csrf_token_storage_strategy = storage_strategy(options[:store] || SessionStore.new)

        before_action :verify_authenticity_token, options
        append_after_action :verify_same_origin_request
      end

      # Turn off request forgery protection. This is a wrapper for:
      #
      #     skip_before_action :verify_authenticity_token
      #
      # See `skip_before_action` for allowed options.
      def skip_forgery_protection(options = {})
        skip_before_action :verify_authenticity_token, options.reverse_merge(raise: false)
      end

      private
        def protection_method_class(name)
          case name
          when :null_session
            ProtectionMethods::NullSession
          when :reset_session
            ProtectionMethods::ResetSession
          when :exception
            ProtectionMethods::Exception
          when Class
            name
          else
            raise ArgumentError, "Invalid request forgery protection method, use :null_session, :exception, :reset_session, or a custom forgery protection class."
          end
        end

        def storage_strategy(name)
          case name
          when :session
            SessionStore.new
          when :cookie
            CookieStore.new(:csrf_token)
          else
            return name if is_storage_strategy?(name)
            raise ArgumentError, "Invalid CSRF token storage strategy, use :session, :cookie, or a custom CSRF token storage class."
          end
        end

        def is_storage_strategy?(object)
          object.respond_to?(:fetch) && object.respond_to?(:store) && object.respond_to?(:reset)
        end
    end

    module ProtectionMethods
      class NullSession
        def initialize(controller)
          @controller = controller
        end

        # This is the method that defines the application behavior when a request is
        # found to be unverified.
        def handle_unverified_request
          request = @controller.request
          request.session = NullSessionHash.new(request)
          request.flash = nil
          request.session_options = { skip: true }
          request.cookie_jar = NullCookieJar.build(request, {})
        end

        private
          class NullSessionHash < Rack::Session::Abstract::SessionHash
            def initialize(req)
              super(nil, req)
              @data = {}
              @loaded = true
            end

            # no-op
            def destroy; end

            def exists?
              true
            end

            def enabled?
              false
            end
          end

          class NullCookieJar < ActionDispatch::Cookies::CookieJar
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
        attr_accessor :warning_message

        def initialize(controller)
          @controller = controller
        end

        def handle_unverified_request
          raise ActionController::InvalidAuthenticityToken, warning_message
        end
      end
    end

    class SessionStore
      def fetch(request)
        request.session[:_csrf_token]
      end

      def store(request, csrf_token)
        request.session[:_csrf_token] = csrf_token
      end

      def reset(request)
        request.session.delete(:_csrf_token)
      end
    end

    class CookieStore
      def initialize(cookie = :csrf_token)
        @cookie_name = cookie
      end

      def fetch(request)
        contents = request.cookie_jar.encrypted[@cookie_name]
        return nil if contents.nil?

        value = JSON.parse(contents)
        return nil unless value.dig("session_id", "public_id") == request.session.id_was&.public_id

        value["token"]
      rescue JSON::ParserError
        nil
      end

      def store(request, csrf_token)
        request.cookie_jar.encrypted.permanent[@cookie_name] = {
          value: {
            token: csrf_token,
            session_id: request.session.id,
          }.to_json,
          httponly: true,
          same_site: :lax,
        }
      end

      def reset(request)
        request.cookie_jar.delete(@cookie_name)
      end
    end

    def initialize(...)
      super
      @_marked_for_same_origin_verification = nil
    end

    def reset_csrf_token(request) # :doc:
      request.env.delete(CSRF_TOKEN)
      csrf_token_storage_strategy.reset(request)
    end

    def commit_csrf_token(request) # :doc:
      csrf_token = request.env[CSRF_TOKEN]
      csrf_token_storage_strategy.store(request, csrf_token) unless csrf_token.nil?
    end

    private
      # The actual before_action that is used to verify the CSRF token. Don't override
      # this directly. Provide your own forgery protection strategy instead. If you
      # override, you'll disable same-origin `<script>` verification.
      #
      # Lean on the protect_from_forgery declaration to mark which actions are due for
      # same-origin request verification. If protect_from_forgery is enabled on an
      # action, this before_action flags its after_action to verify that JavaScript
      # responses are for XHR requests, ensuring they follow the browser's same-origin
      # policy.
      def verify_authenticity_token # :doc:
        mark_for_same_origin_verification!

        if !verified_request?
          logger.warn unverified_request_warning_message if logger && log_warning_on_csrf_failure

          handle_unverified_request
        end
      end

      def handle_unverified_request
        protection_strategy = forgery_protection_strategy.new(self)

        if protection_strategy.respond_to?(:warning_message)
          protection_strategy.warning_message = unverified_request_warning_message
        end

        protection_strategy.handle_unverified_request
      end

      def unverified_request_warning_message
        if valid_request_origin?
          "Can't verify CSRF token authenticity."
        else
          "HTTP Origin header (#{request.origin}) didn't match request.base_url (#{request.base_url})"
        end
      end

      CROSS_ORIGIN_JAVASCRIPT_WARNING = "Security warning: an embedded " \
        "<script> tag on another site requested protected JavaScript. " \
        "If you know what you're doing, go ahead and disable forgery " \
        "protection on this action to permit cross-origin JavaScript embedding."
      private_constant :CROSS_ORIGIN_JAVASCRIPT_WARNING
      # :startdoc:

      # If `verify_authenticity_token` was run (indicating that we have
      # forgery protection enabled for this request) then also verify that we aren't
      # serving an unauthorized cross-origin response.
      def verify_same_origin_request # :doc:
        if marked_for_same_origin_verification? && non_xhr_javascript_response?
          if logger && log_warning_on_csrf_failure
            logger.warn CROSS_ORIGIN_JAVASCRIPT_WARNING
          end
          raise ActionController::InvalidCrossOriginRequest, CROSS_ORIGIN_JAVASCRIPT_WARNING
        end
      end

      # GET requests are checked for cross-origin JavaScript after rendering.
      def mark_for_same_origin_verification! # :doc:
        @_marked_for_same_origin_verification = request.get?
      end

      # If the `verify_authenticity_token` before_action ran, verify that JavaScript
      # responses are only served to same-origin GET requests.
      def marked_for_same_origin_verification? # :doc:
        @_marked_for_same_origin_verification ||= false
      end

      # Check for cross-origin JavaScript responses.
      def non_xhr_javascript_response? # :doc:
        %r(\A(?:text|application)/javascript).match?(media_type) && !request.xhr?
      end

      AUTHENTICITY_TOKEN_LENGTH = 32

      # Returns true or false if a request is verified. Checks:
      #
      # *   Is it a GET or HEAD request? GETs should be safe and idempotent
      # *   Does the form_authenticity_token match the given token value from the
      #     params?
      # *   Does the `X-CSRF-Token` header match the form_authenticity_token?
      #
      def verified_request? # :doc:
        !protect_against_forgery? || request.get? || request.head? ||
          (valid_request_origin? && any_authenticity_token_valid?)
      end

      # Checks if any of the authenticity tokens from the request are valid.
      def any_authenticity_token_valid? # :doc:
        request_authenticity_tokens.any? do |token|
          valid_authenticity_token?(session, token)
        end
      end

      # Possible authenticity tokens sent in the request.
      def request_authenticity_tokens # :doc:
        [form_authenticity_param, request.x_csrf_token]
      end

      # Creates the authenticity token for the current request.
      def form_authenticity_token(form_options: {}) # :doc:
        masked_authenticity_token(form_options: form_options)
      end

      # Creates a masked version of the authenticity token that varies on each
      # request. The masking is used to mitigate SSL attacks like BREACH.
      def masked_authenticity_token(form_options: {})
        action, method = form_options.values_at(:action, :method)

        raw_token = if per_form_csrf_tokens && action && method
          action_path = normalize_action_path(action)
          per_form_csrf_token(nil, action_path, method)
        else
          global_csrf_token
        end

        mask_token(raw_token)
      end

      # Checks the client's masked token to see if it matches the session token.
      # Essentially the inverse of `masked_authenticity_token`.
      def valid_authenticity_token?(session, encoded_masked_token) # :doc:
        if encoded_masked_token.nil? || encoded_masked_token.empty? || !encoded_masked_token.is_a?(String)
          return false
        end

        begin
          masked_token = decode_csrf_token(encoded_masked_token)
        rescue ArgumentError # encoded_masked_token is invalid Base64
          return false
        end

        # See if it's actually a masked token or not. In order to deploy this code, we
        # should be able to handle any unmasked tokens that we've issued without error.

        if masked_token.length == AUTHENTICITY_TOKEN_LENGTH
          # This is actually an unmasked token. This is expected if you have just upgraded
          # to masked tokens, but should stop happening shortly after installing this gem.
          compare_with_real_token masked_token

        elsif masked_token.length == AUTHENTICITY_TOKEN_LENGTH * 2
          csrf_token = unmask_token(masked_token)

          compare_with_global_token(csrf_token) ||
            compare_with_real_token(csrf_token) ||
            valid_per_form_csrf_token?(csrf_token)
        else
          false # Token is malformed.
        end
      end

      def unmask_token(masked_token) # :doc:
        # Split the token into the one-time pad and the encrypted value and decrypt it.
        one_time_pad = masked_token[0...AUTHENTICITY_TOKEN_LENGTH]
        encrypted_csrf_token = masked_token[AUTHENTICITY_TOKEN_LENGTH..-1]
        xor_byte_strings(one_time_pad, encrypted_csrf_token)
      end

      def mask_token(raw_token) # :doc:
        one_time_pad = SecureRandom.random_bytes(AUTHENTICITY_TOKEN_LENGTH)
        encrypted_csrf_token = xor_byte_strings(one_time_pad, raw_token)
        masked_token = one_time_pad + encrypted_csrf_token
        encode_csrf_token(masked_token)
      end

      def compare_with_real_token(token, session = nil) # :doc:
        ActiveSupport::SecurityUtils.fixed_length_secure_compare(token, real_csrf_token(session))
      end

      def compare_with_global_token(token, session = nil) # :doc:
        ActiveSupport::SecurityUtils.fixed_length_secure_compare(token, global_csrf_token(session))
      end

      def valid_per_form_csrf_token?(token, session = nil) # :doc:
        if per_form_csrf_tokens
          correct_token = per_form_csrf_token(
            session,
            request.path.chomp("/"),
            request.request_method
          )

          ActiveSupport::SecurityUtils.fixed_length_secure_compare(token, correct_token)
        else
          false
        end
      end

      def real_csrf_token(_session = nil) # :doc:
        csrf_token = request.env.fetch(CSRF_TOKEN) do
          request.env[CSRF_TOKEN] = csrf_token_storage_strategy.fetch(request) || generate_csrf_token
        end

        decode_csrf_token(csrf_token)
      end

      def per_form_csrf_token(session, action_path, method) # :doc:
        csrf_token_hmac(session, [action_path, method.downcase].join("#"))
      end

      GLOBAL_CSRF_TOKEN_IDENTIFIER = "!real_csrf_token"
      private_constant :GLOBAL_CSRF_TOKEN_IDENTIFIER

      def global_csrf_token(session = nil) # :doc:
        csrf_token_hmac(session, GLOBAL_CSRF_TOKEN_IDENTIFIER)
      end

      def csrf_token_hmac(session, identifier) # :doc:
        OpenSSL::HMAC.digest(
          OpenSSL::Digest::SHA256.new,
          real_csrf_token(session),
          identifier
        )
      end

      def xor_byte_strings(s1, s2) # :doc:
        s2 = s2.dup
        size = s1.bytesize
        i = 0
        while i < size
          s2.setbyte(i, s1.getbyte(i) ^ s2.getbyte(i))
          i += 1
        end
        s2
      end

      # The form's authenticity parameter. Override to provide your own.
      def form_authenticity_param # :doc:
        params[request_forgery_protection_token]
      end

      # Checks if the controller allows forgery protection.
      def protect_against_forgery? # :doc:
        allow_forgery_protection && (!session.respond_to?(:enabled?) || session.enabled?)
      end

      NULL_ORIGIN_MESSAGE = <<~MSG
        The browser returned a 'null' origin for a request with origin-based forgery protection turned on. This usually
        means you have the 'no-referrer' Referrer-Policy header enabled, or that the request came from a site that
        refused to give its origin. This makes it impossible for Rails to verify the source of the requests. Likely the
        best solution is to change your referrer policy to something less strict like same-origin or strict-origin.
        If you cannot change the referrer policy, you can disable origin checking with the
        Rails.application.config.action_controller.forgery_protection_origin_check setting.
      MSG

      # Checks if the request originated from the same origin by looking at the Origin
      # header.
      def valid_request_origin? # :doc:
        if forgery_protection_origin_check
          # We accept blank origin headers because some user agents don't send it.
          raise InvalidAuthenticityToken, NULL_ORIGIN_MESSAGE if request.origin == "null"
          request.origin.nil? || request.origin == request.base_url
        else
          true
        end
      end

      def normalize_action_path(action_path) # :doc:
        uri = URI.parse(action_path)

        if uri.relative? && (action_path.blank? || !action_path.start_with?("/"))
          normalize_relative_action_path(uri.path)
        else
          uri.path.chomp("/")
        end
      end

      def normalize_relative_action_path(rel_action_path) # :doc:
        uri = URI.parse(request.path)
        # add the action path to the request.path
        uri.path += "/#{rel_action_path}"
        # relative path with "./path"
        uri.path.gsub!("/./", "/")

        uri.path.chomp("/")
      end

      def generate_csrf_token
        SecureRandom.urlsafe_base64(AUTHENTICITY_TOKEN_LENGTH)
      end

      def encode_csrf_token(csrf_token)
        Base64.urlsafe_encode64(csrf_token, padding: false)
      end

      def decode_csrf_token(encoded_csrf_token)
        Base64.urlsafe_decode64(encoded_csrf_token)
      end
  end
end
