# frozen_string_literal: true

# :markup: markdown

require "rack/session/abstract/id"
require "action_controller/metal/exceptions"
require "active_support/security_utils"

module ActionController # :nodoc:
  class InvalidCrossOriginRequest < ActionControllerError # :nodoc:
  end

  include ActiveSupport::Deprecation::DeprecatedConstantAccessor
  deprecate_constant "InvalidAuthenticityToken", "ActionController::InvalidCrossOriginRequest",
    deprecator: ActionController.deprecator,
    message: "ActionController::InvalidAuthenticityToken has been deprecated and will be removed in Rails 9.0. Use ActionController::InvalidCrossOriginRequest instead."

  # # Action Controller Request Forgery Protection
  #
  # Controller actions are protected from Cross-Site Request Forgery (CSRF)
  # attacks by checking the Sec-Fetch-Site header sent by modern browsers to
  # indicate the relationship between request's initiator origin and the origin
  # of the requested resource
  # (https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Site)
  #
  # For applications that need to support older browsers, there's a token-based
  # fallback. A token is included in the rendered HTML for your application. This
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
  # ActionController::InvalidCrossOriginRequest error on unverified requests.
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
      singleton_class.delegate :request_forgery_protection_token, :request_forgery_protection_token=, to: :config
      delegate :request_forgery_protection_token, :request_forgery_protection_token=, to: :config
      self.request_forgery_protection_token ||= :authenticity_token

      # Holds the class which implements the request forgery protection.
      singleton_class.delegate :forgery_protection_strategy, :forgery_protection_strategy=, to: :config
      delegate :forgery_protection_strategy, :forgery_protection_strategy=, to: :config
      self.forgery_protection_strategy = nil

      # Controls whether request forgery protection is turned on or not. Turned off by
      # default only in test mode.
      singleton_class.delegate :allow_forgery_protection, :allow_forgery_protection=, to: :config
      delegate :allow_forgery_protection, :allow_forgery_protection=, to: :config
      self.allow_forgery_protection = true if allow_forgery_protection.nil?

      # Controls whether a CSRF failure logs a warning. On by default.
      singleton_class.delegate :log_warning_on_csrf_failure, :log_warning_on_csrf_failure=, to: :config
      delegate :log_warning_on_csrf_failure, :log_warning_on_csrf_failure=, to: :config
      self.log_warning_on_csrf_failure = true

      # Controls whether the Origin header is checked in addition to the CSRF token.
      singleton_class.delegate :forgery_protection_origin_check, :forgery_protection_origin_check=, to: :config
      delegate :forgery_protection_origin_check, :forgery_protection_origin_check=, to: :config
      self.forgery_protection_origin_check = false

      # Controls whether form-action/method specific CSRF tokens are used.
      singleton_class.delegate :per_form_csrf_tokens, :per_form_csrf_tokens=, to: :config
      delegate :per_form_csrf_tokens, :per_form_csrf_tokens=, to: :config
      self.per_form_csrf_tokens = false

      # The strategy to use for storing and retrieving CSRF tokens.
      singleton_class.delegate :csrf_token_storage_strategy, :csrf_token_storage_strategy=, to: :config
      delegate :csrf_token_storage_strategy, :csrf_token_storage_strategy=, to: :config
      self.csrf_token_storage_strategy = SessionStore.new

      # The strategy to use for verifying requests. Options are:
      # * :header_only - Use Sec-Fetch-Site header only (default, modern browsers)
      # * :header_or_legacy_token - Combined approach: Sec-Fetch-Site with fallback to token
      singleton_class.delegate :forgery_protection_verification_strategy, :forgery_protection_verification_strategy=, to: :config
      delegate :forgery_protection_verification_strategy, :forgery_protection_verification_strategy=, to: :config
      self.forgery_protection_verification_strategy = :header_or_legacy_token

      # Origins allowed for cross-site requests, such as OAuth/SSO callbacks,
      # third-party embeds, and legitimate remote form submission.
      # Example: %w[ https://accounts.google.com ]
      singleton_class.delegate :forgery_protection_trusted_origins, :forgery_protection_trusted_origins=, to: :config
      delegate :forgery_protection_trusted_origins, :forgery_protection_trusted_origins=, to: :config
      self.forgery_protection_trusted_origins = []

      # Controls the default strategy used when calling protect_from_forgery without arguments.
      # Defaults to :null_session for backwards compatibility, but will change to :exception
      # in a future version of Rails.
      singleton_class.delegate :default_protect_from_forgery_with, :default_protect_from_forgery_with=, to: :config
      delegate :default_protect_from_forgery_with, :default_protect_from_forgery_with=, to: :config
      self.default_protect_from_forgery_with = :null_session

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
      # *   `:with` - Set the method to handle unverified request. If not specified,
      #     defaults to the value of `config.action_controller.default_protect_from_forgery_with`,
      #     which is `:null_session` by default but will change to `:exception` in a
      #     future version of Rails. You can opt into the new behavior now by setting
      #     `config.action_controller.default_protect_from_forgery_with = :exception`.
      #     Note if `default_protect_from_forgery` is true, Rails calls
      #     protect_from_forgery with `with: :exception`.
      #
      #
      # Built-in unverified request handling methods are:
      #
      # *   `:exception` - Raises ActionController::InvalidCrossOriginRequest
      #     exception.
      # *   `:reset_session` - Resets the session.
      # *   `:null_session` - Provides an empty session during request but doesn't
      #     reset it completely. Currently used as default if `:with` option is not
      #     specified, but this will change to `:exception` in a future version of Rails.
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
      #
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
      #
      # *   `:using` - Set the verification strategy for CSRF protection.
      #
      #     Built-in verification strategies are:
      #
      #     *   `:header_only` - Uses the `Sec-Fetch-Site` header sent by modern
      #         browsers to verify that requests originate from the same site. This
      #         approach does not require authenticity tokens but only works with
      #         browsers that support the Fetch Metadata Request Headers. Requests
      #         without a valid `Sec-Fetch-Site` header will be rejected. This is
      #         the default.
      #
      #     *   `:header_or_legacy_token` - A hybrid approach that first checks the
      #         `Sec-Fetch-Site` header. If the header indicates same-site or
      #         same-origin, the request is allowed. Requests with a cross-site
      #         value are rejected. When the header is missing or "none", it falls
      #         back to checking the authenticity token. This mode logs when
      #         falling back to help identify requests that should be fixed to work
      #         with `:header_only`. Use this if you need to support older browsers
      #         that don't send the `Sec-Fetch-Site` header.
      #
      # *   `:trusted_origins` - Array of origins to allow for cross-site requests,
      #     such as OAuth/SSO callbacks, third-party embeds, and legitimate remote
      #     form submission.
      #
      # Example:
      #
      #     class ApplicationController < ActionController::Base
      #       # Modern browsers only (default)
      #       protect_from_forgery using: :header_only, with: :exception
      #
      #       # Hybrid approach with fallback for older browsers
      #       protect_from_forgery using: :header_or_legacy_token, with: :exception
      #
      #       # Allow cross-site requests from trusted origins
      #       protect_from_forgery trusted_origins: %w[ https://accounts.google.com ]
      #     end
      def protect_from_forgery(options = {})
        options = options.reverse_merge(prepend: false)

        strategy = if options.key?(:with)
          options[:with]
        else
          if default_protect_from_forgery_with == :null_session
            ActionController.deprecator.warn(<<~MSG.squish)
              Calling `protect_from_forgery` without specifying a strategy is deprecated
              and will default to `with: :exception` in a future version of Rails. To opt into the new
              behavior now, use `config.action_controller.default_protect_from_forgery_with = :exception`.
              To silence this warning without changing behavior, explicitly pass
              `protect_from_forgery with: :null_session`.
            MSG
          end
          default_protect_from_forgery_with
        end

        self.forgery_protection_strategy = protection_method_class(strategy)
        self.request_forgery_protection_token ||= :authenticity_token

        self.csrf_token_storage_strategy = storage_strategy(options[:store] || SessionStore.new)
        self.forgery_protection_verification_strategy = verification_strategy(options[:using] || forgery_protection_verification_strategy)
        self.forgery_protection_trusted_origins = Array(options[:trusted_origins]) if options.key?(:trusted_origins)

        if options[:prepend]
          prepend_before_action :verify_request_for_forgery_protection, options
          prepend_before_action :verify_authenticity_token, options
        else
          before_action :verify_authenticity_token, :verify_request_for_forgery_protection, options
        end
        append_after_action :verify_same_origin_request
        append_after_action :append_sec_fetch_site_to_vary_header, options
      end

      # Turn off request forgery protection. This is a wrapper for:
      #
      #     skip_before_action :verify_request_for_forgery_protection
      #     skip_after_action :append_sec_fetch_site_to_vary_header
      #
      # See `skip_before_action` for allowed options.
      def skip_forgery_protection(options = {})
        options = options.reverse_merge(raise: false)
        skip_before_action :verify_request_for_forgery_protection, options
        skip_after_action :append_sec_fetch_site_to_vary_header, options
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

        def verification_strategy(name)
          case name
          when :header_only, :header_or_legacy_token
            name
          else
            raise ArgumentError, "Invalid request forgery verification strategy, use :header_only or :header_or_legacy_token."
          end
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
          raise ActionController::InvalidCrossOriginRequest, warning_message
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
      @_verify_authenticity_token_ran = false
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
      def verify_authenticity_token # :nodoc:
        # This method was renamed to verify_request_for_forgery_protection, to more accurately
        # reflect its purpose now that an authenticity token is not necessarily verified.
        # However, because many people rely on `skip_before_action :verify_authenticity_token`,
        # to opt out of forgery protection, we need to keep this working and deprecate it.
        # We simply mark it as run, as part of protect_from_forgery, and when verifying the
        # request, we check if the method ran. If it didn't, it's because it was skipped
        # on its own and not via skip_forgery_protection, so we can emit the deprecation warning
        @_verify_authenticity_token_ran = true
      end

      # The actual before_action that is used to verify the request to protect from forgery.
      # Don't override this directly. Provide your own forgery protection strategy instead.
      # If you override, you'll disable same-origin `<script>` verification.
      #
      # Lean on the protect_from_forgery declaration to mark which actions are due for
      # same-origin request verification. If protect_from_forgery is enabled on an
      # action, this before_action flags its after_action to verify that JavaScript
      # responses are for XHR requests, ensuring they follow the browser's same-origin
      # policy.
      def verify_request_for_forgery_protection # :doc:
        if @_verify_authenticity_token_ran
          mark_for_same_origin_verification!

          if !verified_request?
            instrument_unverified_request

            handle_unverified_request
          end
        else
          ActiveSupport.deprecator.warn(<<~MSG.squish)
            `verify_authenticity_token` is deprecated and will be removed in a future Rails version.
            To skip forgery protection, use `skip_forgery_protection` instead of skipping `verify_authenticity_token`
            as this won't have any effect in a future Rails version.
          MSG
        end
      end

      def handle_unverified_request
        protection_strategy = forgery_protection_strategy.new(self)

        if protection_strategy.respond_to?(:warning_message)
          protection_strategy.warning_message = unverified_request_warning_message
        end

        protection_strategy.handle_unverified_request
      end

      def cross_origin_request?
        !valid_request_origin? ||
          sec_fetch_site_value == "cross-site" ||
          using_header_only_for_forgery_protection?
      end

      def unverified_request_warning_message
        if !valid_request_origin?
          "HTTP Origin header (#{request.origin}) didn't match request.base_url (#{request.base_url})"
        elsif sec_fetch_site_value == "cross-site"
          "Sec-Fetch-Site header (cross-site) indicates a cross-site request"
        elsif using_header_only_for_forgery_protection?
          "Sec-Fetch-Site header is missing or invalid (#{sec_fetch_site_value.inspect})"
        else
          "Can't verify CSRF token authenticity."
        end
      end

      CROSS_ORIGIN_JAVASCRIPT_WARNING = "Security warning: an embedded " \
        "<script> tag on another site requested protected JavaScript. " \
        "If you know what you're doing, go ahead and disable forgery " \
        "protection on this action to permit cross-origin JavaScript embedding."
      private_constant :CROSS_ORIGIN_JAVASCRIPT_WARNING
      # :startdoc:

      # If `verify_request_for_forgery_protection` was run (indicating that we have
      # forgery protection enabled for this request) then also verify that we aren't
      # serving an unauthorized cross-origin response.
      def verify_same_origin_request # :doc:
        if marked_for_same_origin_verification? && non_xhr_javascript_response?
          instrument_cross_origin_javascript
          raise ActionController::InvalidCrossOriginRequest, CROSS_ORIGIN_JAVASCRIPT_WARNING
        end
      end

      # Appends Sec-Fetch-Site to the Vary header. This ensures proper cache behavior since
      # the response may vary based on this header.
      def append_sec_fetch_site_to_vary_header # :doc:
        vary_header = response.headers["Vary"].to_s.split(",").map(&:strip).reject(&:blank?)
        unless vary_header.include?("Sec-Fetch-Site")
          response.headers["Vary"] = (vary_header + ["Sec-Fetch-Site"]).join(", ")
        end
      end

      # GET requests are checked for cross-origin JavaScript after rendering.
      def mark_for_same_origin_verification! # :doc:
        @_marked_for_same_origin_verification = request.get?
      end

      # If the `verify_request_for_forgery_protection` before_action ran,
      # verify that JavaScript responses are only served to same-origin
      # GET requests.
      def marked_for_same_origin_verification? # :doc:
        @_marked_for_same_origin_verification ||= false
      end

      # Check for cross-origin JavaScript responses.
      def non_xhr_javascript_response? # :doc:
        %r(\A(?:text|application)/javascript).match?(media_type) && !request.xhr?
      end

      AUTHENTICITY_TOKEN_LENGTH = 32

      # Safe values for Sec-Fetch-Site header that indicate the request
      # originated from the same site.
      SAFE_FETCH_SITES = %w[ same-origin same-site ].freeze
      private_constant :SAFE_FETCH_SITES

      # Returns true or false if a request is verified. The verification method
      # depends on the configured `forgery_protection_verification_strategy`:
      #
      # *   `:header_only` - Uses Sec-Fetch-Site header only (default)
      # *   `:header_or_legacy_token` - Uses Sec-Fetch-Site header with fallback to token
      #
      # For all strategies, GET and HEAD requests are allowed without verification.
      #
      def verified_request? # :doc:
        request.get? || request.head? || !protect_against_forgery? ||
          (valid_request_origin? && verified_request_for_forgery_protection?)
      end

      def verified_request_for_forgery_protection?
        if using_header_only_for_forgery_protection?
          verified_via_header_only?
        else
          verified_with_legacy_token?
        end
      end

      def using_header_only_for_forgery_protection?
        forgery_protection_verification_strategy == :header_only
      end

      def verified_via_header_only?
        case sec_fetch_site_value
        when "same-origin", "same-site"
          true
        when "cross-site"
          origin_trusted?
        when nil
          !request.ssl? && !ActionDispatch::Http::URL.secure_protocol
        else
          false
        end
      end

      def verified_with_legacy_token?
        case sec_fetch_site_value
        when "same-origin", "same-site"
          true
        when "cross-site"
          origin_trusted?
        else # "none" or missing
          instrument_csrf_token_fallback
          any_authenticity_token_valid?
        end
      end

      def instrument_csrf_token_fallback
        instrument_csrf_event "csrf_token_fallback.action_controller"
      end

      def instrument_unverified_request
        instrument_csrf_event "csrf_request_blocked.action_controller",
          message: unverified_request_warning_message
      end

      def instrument_cross_origin_javascript
        instrument_csrf_event "csrf_javascript_blocked.action_controller",
          message: CROSS_ORIGIN_JAVASCRIPT_WARNING
      end

      def instrument_csrf_event(event, message: nil)
        ActiveSupport::Notifications.instrument event,
          request: request,
          controller: self.class.name,
          action: action_name,
          sec_fetch_site: sec_fetch_site_value,
          message: message
      end

      def origin_trusted?
        origin = request.origin
        origin.present? && forgery_protection_trusted_origins.include?(origin)
      end

      # Returns the normalized value of the Sec-Fetch-Site header.
      def sec_fetch_site_value # :doc:
        if value = request.headers["Sec-Fetch-Site"]
          value.to_s.downcase.presence
        end
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
        if !encoded_masked_token.is_a?(String) || encoded_masked_token.empty?
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
      private_constant :NULL_ORIGIN_MESSAGE

      # Checks if the request originated from the same origin by looking at the Origin
      # header.
      def valid_request_origin? # :doc:
        if forgery_protection_origin_check
          # We accept blank origin headers because some user agents don't send it.
          raise InvalidCrossOriginRequest, NULL_ORIGIN_MESSAGE if request.origin == "null"
          request.origin.nil? || request.origin == request.base_url
        else
          true
        end
      end

      def normalize_action_path(action_path)
        uri = URI.parse(action_path)

        if uri.relative? && (action_path.blank? || !action_path.start_with?("/"))
          normalize_relative_action_path(uri.path)
        else
          uri.path.chomp("/")
        end
      end

      def normalize_relative_action_path(rel_action_path)
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
