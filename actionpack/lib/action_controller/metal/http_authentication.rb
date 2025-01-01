# frozen_string_literal: true

# :markup: markdown

require "base64"
require "active_support/security_utils"
require "active_support/core_ext/array/access"

module ActionController
  # HTTP Basic, Digest, and Token authentication.
  module HttpAuthentication
    # # HTTP Basic authentication
    #
    # ### Simple Basic example
    #
    #     class PostsController < ApplicationController
    #       http_basic_authenticate_with name: "dhh", password: "secret", except: :index
    #
    #       def index
    #         render plain: "Everyone can see me!"
    #       end
    #
    #       def edit
    #         render plain: "I'm only accessible if you know the password"
    #       end
    #     end
    #
    # ### Advanced Basic example
    #
    # Here is a more advanced Basic example where only Atom feeds and the XML API
    # are protected by HTTP authentication. The regular HTML interface is protected
    # by a session approach:
    #
    #     class ApplicationController < ActionController::Base
    #       before_action :set_account, :authenticate
    #
    #       private
    #         def set_account
    #           @account = Account.find_by(url_name: request.subdomains.first)
    #         end
    #
    #         def authenticate
    #           case request.format
    #           when Mime[:xml], Mime[:atom]
    #             if user = authenticate_with_http_basic { |u, p| @account.users.authenticate(u, p) }
    #               @current_user = user
    #             else
    #               request_http_basic_authentication
    #             end
    #           else
    #             if session_authenticated?
    #               @current_user = @account.users.find(session[:authenticated][:user_id])
    #             else
    #               redirect_to(login_url) and return false
    #             end
    #           end
    #         end
    #     end
    #
    # In your integration tests, you can do something like this:
    #
    #     def test_access_granted_from_xml
    #       authorization = ActionController::HttpAuthentication::Basic.encode_credentials(users(:dhh).name, users(:dhh).password)
    #
    #       get "/notes/1.xml", headers: { 'HTTP_AUTHORIZATION' => authorization }
    #
    #       assert_equal 200, status
    #     end
    module Basic
      extend self

      module ControllerMethods
        extend ActiveSupport::Concern

        module ClassMethods
          # Enables HTTP Basic authentication.
          #
          # See ActionController::HttpAuthentication::Basic for example usage.
          def http_basic_authenticate_with(name:, password:, realm: nil, **options)
            raise ArgumentError, "Expected name: to be a String, got #{name.class}" unless name.is_a?(String)
            raise ArgumentError, "Expected password: to be a String, got #{password.class}" unless password.is_a?(String)
            before_action(options) { http_basic_authenticate_or_request_with name: name, password: password, realm: realm }
          end
        end

        def http_basic_authenticate_or_request_with(name:, password:, realm: nil, message: nil)
          authenticate_or_request_with_http_basic(realm, message) do |given_name, given_password|
            # This comparison uses & so that it doesn't short circuit and uses
            # `secure_compare` so that length information isn't leaked.
            ActiveSupport::SecurityUtils.secure_compare(given_name.to_s, name) &
              ActiveSupport::SecurityUtils.secure_compare(given_password.to_s, password)
          end
        end

        def authenticate_or_request_with_http_basic(realm = nil, message = nil, &login_procedure)
          authenticate_with_http_basic(&login_procedure) || request_http_basic_authentication(realm || "Application", message)
        end

        def authenticate_with_http_basic(&login_procedure)
          HttpAuthentication::Basic.authenticate(request, &login_procedure)
        end

        def request_http_basic_authentication(realm = "Application", message = nil)
          HttpAuthentication::Basic.authentication_request(self, realm, message)
        end
      end

      def authenticate(request, &login_procedure)
        if has_basic_credentials?(request)
          login_procedure.call(*user_name_and_password(request))
        end
      end

      def has_basic_credentials?(request)
        request.authorization.present? && (auth_scheme(request).downcase == "basic")
      end

      def user_name_and_password(request)
        decode_credentials(request).split(":", 2)
      end

      def decode_credentials(request)
        ::Base64.decode64(auth_param(request) || "")
      end

      def auth_scheme(request)
        request.authorization.to_s.split(" ", 2).first
      end

      def auth_param(request)
        request.authorization.to_s.split(" ", 2).second
      end

      def encode_credentials(user_name, password)
        "Basic #{::Base64.strict_encode64("#{user_name}:#{password}")}"
      end

      def authentication_request(controller, realm, message)
        message ||= "HTTP Basic: Access denied.\n"
        controller.headers["WWW-Authenticate"] = %(Basic realm="#{realm.tr('"', "")}")
        controller.status = 401
        controller.response_body = message
      end
    end

    # # HTTP Digest authentication
    #
    # ### Simple Digest example
    #
    #     require "openssl"
    #     class PostsController < ApplicationController
    #       REALM = "SuperSecret"
    #       USERS = {"dhh" => "secret", #plain text password
    #                "dap" => OpenSSL::Digest::MD5.hexdigest(["dap",REALM,"secret"].join(":"))}  #ha1 digest password
    #
    #       before_action :authenticate, except: [:index]
    #
    #       def index
    #         render plain: "Everyone can see me!"
    #       end
    #
    #       def edit
    #         render plain: "I'm only accessible if you know the password"
    #       end
    #
    #       private
    #         def authenticate
    #           authenticate_or_request_with_http_digest(REALM) do |username|
    #             USERS[username]
    #           end
    #         end
    #     end
    #
    # ### Notes
    #
    # The `authenticate_or_request_with_http_digest` block must return the user's
    # password or the ha1 digest hash so the framework can appropriately hash to
    # check the user's credentials. Returning `nil` will cause authentication to
    # fail.
    #
    # Storing the ha1 hash: MD5(username:realm:password), is better than storing a
    # plain password. If the password file or database is compromised, the attacker
    # would be able to use the ha1 hash to authenticate as the user at this `realm`,
    # but would not have the user's password to try using at other sites.
    #
    # In rare instances, web servers or front proxies strip authorization headers
    # before they reach your application. You can debug this situation by logging
    # all environment variables, and check for HTTP_AUTHORIZATION, amongst others.
    module Digest
      extend self

      module ControllerMethods
        # Authenticate using an HTTP Digest, or otherwise render an HTTP header
        # requesting the client to send a Digest.
        #
        # See ActionController::HttpAuthentication::Digest for example usage.
        def authenticate_or_request_with_http_digest(realm = "Application", message = nil, &password_procedure)
          authenticate_with_http_digest(realm, &password_procedure) || request_http_digest_authentication(realm, message)
        end

        # Authenticate using an HTTP Digest. Returns true if authentication is
        # successful, false otherwise.
        def authenticate_with_http_digest(realm = "Application", &password_procedure)
          HttpAuthentication::Digest.authenticate(request, realm, &password_procedure)
        end

        # Render an HTTP header requesting the client to send a Digest for
        # authentication.
        def request_http_digest_authentication(realm = "Application", message = nil)
          HttpAuthentication::Digest.authentication_request(self, realm, message)
        end
      end

      # Returns true on a valid response, false otherwise.
      def authenticate(request, realm, &password_procedure)
        request.authorization && validate_digest_response(request, realm, &password_procedure)
      end

      # Returns false unless the request credentials response value matches the
      # expected value. First try the password as a ha1 digest password. If this
      # fails, then try it as a plain text password.
      def validate_digest_response(request, realm, &password_procedure)
        secret_key  = secret_token(request)
        credentials = decode_credentials_header(request)
        valid_nonce = validate_nonce(secret_key, request, credentials[:nonce])

        if valid_nonce && realm == credentials[:realm] && opaque(secret_key) == credentials[:opaque]
          password = password_procedure.call(credentials[:username])
          return false unless password

          method = request.get_header("rack.methodoverride.original_method") || request.get_header("REQUEST_METHOD")
          uri    = credentials[:uri]

          [true, false].any? do |trailing_question_mark|
            [true, false].any? do |password_is_ha1|
              _uri = trailing_question_mark ? uri + "?" : uri
              expected = expected_response(method, _uri, credentials, password, password_is_ha1)
              expected == credentials[:response]
            end
          end
        end
      end

      # Returns the expected response for a request of `http_method` to `uri` with the
      # decoded `credentials` and the expected `password` Optional parameter
      # `password_is_ha1` is set to `true` by default, since best practice is to store
      # ha1 digest instead of a plain-text password.
      def expected_response(http_method, uri, credentials, password, password_is_ha1 = true)
        ha1 = password_is_ha1 ? password : ha1(credentials, password)
        ha2 = OpenSSL::Digest::MD5.hexdigest([http_method.to_s.upcase, uri].join(":"))
        OpenSSL::Digest::MD5.hexdigest([ha1, credentials[:nonce], credentials[:nc], credentials[:cnonce], credentials[:qop], ha2].join(":"))
      end

      def ha1(credentials, password)
        OpenSSL::Digest::MD5.hexdigest([credentials[:username], credentials[:realm], password].join(":"))
      end

      def encode_credentials(http_method, credentials, password, password_is_ha1)
        credentials[:response] = expected_response(http_method, credentials[:uri], credentials, password, password_is_ha1)
        "Digest " + credentials.sort_by { |x| x[0].to_s }.map { |v| "#{v[0]}='#{v[1]}'" }.join(", ")
      end

      def decode_credentials_header(request)
        decode_credentials(request.authorization)
      end

      def decode_credentials(header)
        ActiveSupport::HashWithIndifferentAccess[header.to_s.gsub(/^Digest\s+/, "").split(",").map do |pair|
          key, value = pair.split("=", 2)
          [key.strip, value.to_s.gsub(/^"|"$/, "").delete("'")]
        end]
      end

      def authentication_header(controller, realm)
        secret_key = secret_token(controller.request)
        nonce = self.nonce(secret_key)
        opaque = opaque(secret_key)
        controller.headers["WWW-Authenticate"] = %(Digest realm="#{realm}", qop="auth", algorithm=MD5, nonce="#{nonce}", opaque="#{opaque}")
      end

      def authentication_request(controller, realm, message = nil)
        message ||= "HTTP Digest: Access denied.\n"
        authentication_header(controller, realm)
        controller.status = 401
        controller.response_body = message
      end

      def secret_token(request)
        key_generator  = request.key_generator
        http_auth_salt = request.http_auth_salt
        key_generator.generate_key(http_auth_salt)
      end

      # Uses an MD5 digest based on time to generate a value to be used only once.
      #
      # A server-specified data string which should be uniquely generated each time a
      # 401 response is made. It is recommended that this string be base64 or
      # hexadecimal data. Specifically, since the string is passed in the header lines
      # as a quoted string, the double-quote character is not allowed.
      #
      # The contents of the nonce are implementation dependent. The quality of the
      # implementation depends on a good choice. A nonce might, for example, be
      # constructed as the base 64 encoding of
      #
      #     time-stamp H(time-stamp ":" ETag ":" private-key)
      #
      # where time-stamp is a server-generated time or other non-repeating value, ETag
      # is the value of the HTTP ETag header associated with the requested entity, and
      # private-key is data known only to the server. With a nonce of this form a
      # server would recalculate the hash portion after receiving the client
      # authentication header and reject the request if it did not match the nonce
      # from that header or if the time-stamp value is not recent enough. In this way
      # the server can limit the time of the nonce's validity. The inclusion of the
      # ETag prevents a replay request for an updated version of the resource. (Note:
      # including the IP address of the client in the nonce would appear to offer the
      # server the ability to limit the reuse of the nonce to the same client that
      # originally got it. However, that would break proxy farms, where requests from
      # a single user often go through different proxies in the farm. Also, IP address
      # spoofing is not that hard.)
      #
      # An implementation might choose not to accept a previously used nonce or a
      # previously used digest, in order to protect against a replay attack. Or, an
      # implementation might choose to use one-time nonces or digests for POST, PUT,
      # or PATCH requests, and a time-stamp for GET requests. For more details on the
      # issues involved see Section 4 of this document.
      #
      # The nonce is opaque to the client. Composed of Time, and hash of Time with
      # secret key from the Rails session secret generated upon creation of project.
      # Ensures the time cannot be modified by client.
      def nonce(secret_key, time = Time.now)
        t = time.to_i
        hashed = [t, secret_key]
        digest = OpenSSL::Digest::MD5.hexdigest(hashed.join(":"))
        ::Base64.strict_encode64("#{t}:#{digest}")
      end

      # Might want a shorter timeout depending on whether the request is a PATCH, PUT,
      # or POST, and if the client is a browser or web service. Can be much shorter if
      # the Stale directive is implemented. This would allow a user to use new nonce
      # without prompting the user again for their username and password.
      def validate_nonce(secret_key, request, value, seconds_to_timeout = 5 * 60)
        return false if value.nil?
        t = ::Base64.decode64(value).split(":").first.to_i
        nonce(secret_key, t) == value && (t - Time.now.to_i).abs <= seconds_to_timeout
      end

      # Opaque based on digest of secret key
      def opaque(secret_key)
        OpenSSL::Digest::MD5.hexdigest(secret_key)
      end
    end

    # # HTTP Token authentication
    #
    # ### Simple Token example
    #
    #     class PostsController < ApplicationController
    #       TOKEN = "secret"
    #
    #       before_action :authenticate, except: [ :index ]
    #
    #       def index
    #         render plain: "Everyone can see me!"
    #       end
    #
    #       def edit
    #         render plain: "I'm only accessible if you know the password"
    #       end
    #
    #       private
    #         def authenticate
    #           authenticate_or_request_with_http_token do |token, options|
    #             # Compare the tokens in a time-constant manner, to mitigate
    #             # timing attacks.
    #             ActiveSupport::SecurityUtils.secure_compare(token, TOKEN)
    #           end
    #         end
    #     end
    #
    # Here is a more advanced Token example where only Atom feeds and the XML API
    # are protected by HTTP token authentication. The regular HTML interface is
    # protected by a session approach:
    #
    #     class ApplicationController < ActionController::Base
    #       before_action :set_account, :authenticate
    #
    #       private
    #         def set_account
    #           @account = Account.find_by(url_name: request.subdomains.first)
    #         end
    #
    #         def authenticate
    #           case request.format
    #           when Mime[:xml], Mime[:atom]
    #             if user = authenticate_with_http_token { |t, o| @account.users.authenticate(t, o) }
    #               @current_user = user
    #             else
    #               request_http_token_authentication
    #             end
    #           else
    #             if session_authenticated?
    #               @current_user = @account.users.find(session[:authenticated][:user_id])
    #             else
    #               redirect_to(login_url) and return false
    #             end
    #           end
    #         end
    #     end
    #
    # In your integration tests, you can do something like this:
    #
    #     def test_access_granted_from_xml
    #       authorization = ActionController::HttpAuthentication::Token.encode_credentials(users(:dhh).token)
    #
    #       get "/notes/1.xml", headers: { 'HTTP_AUTHORIZATION' => authorization }
    #
    #       assert_equal 200, status
    #     end
    #
    # On shared hosts, Apache sometimes doesn't pass authentication headers to FCGI
    # instances. If your environment matches this description and you cannot
    # authenticate, try this rule in your Apache setup:
    #
    #     RewriteRule ^(.*)$ dispatch.fcgi [E=X-HTTP_AUTHORIZATION:%{HTTP:Authorization},QSA,L]
    module Token
      TOKEN_KEY = "token="
      TOKEN_REGEX = /^(Token|Bearer)\s+/
      AUTHN_PAIR_DELIMITERS = /(?:,|;|\t)/
      extend self

      module ControllerMethods
        # Authenticate using an HTTP Bearer token, or otherwise render an HTTP header
        # requesting the client to send a Bearer token. For the authentication to be
        # considered successful, `login_procedure` must not return a false value.
        # Typically, the authenticated user is returned.
        #
        # See ActionController::HttpAuthentication::Token for example usage.
        def authenticate_or_request_with_http_token(realm = "Application", message = nil, &login_procedure)
          authenticate_with_http_token(&login_procedure) || request_http_token_authentication(realm, message)
        end

        # Authenticate using an HTTP Bearer token. Returns the return value of
        # `login_procedure` if a token is found. Returns `nil` if no token is found.
        #
        # See ActionController::HttpAuthentication::Token for example usage.
        def authenticate_with_http_token(&login_procedure)
          Token.authenticate(self, &login_procedure)
        end

        # Render an HTTP header requesting the client to send a Bearer token for
        # authentication.
        def request_http_token_authentication(realm = "Application", message = nil)
          Token.authentication_request(self, realm, message)
        end
      end

      # If token Authorization header is present, call the login procedure with the
      # present token and options.
      #
      # Returns the return value of `login_procedure` if a token is found. Returns
      # `nil` if no token is found.
      #
      # #### Parameters
      #
      # *   `controller` - ActionController::Base instance for the current request.
      # *   `login_procedure` - Proc to call if a token is present. The Proc should
      #     take two arguments:
      #
      #         authenticate(controller) { |token, options| ... }
      #
      #
      def authenticate(controller, &login_procedure)
        token, options = token_and_options(controller.request)
        unless token.blank?
          login_procedure.call(token, options)
        end
      end

      # Parses the token and options out of the token Authorization header. The value
      # for the Authorization header is expected to have the prefix `"Token"` or
      # `"Bearer"`. If the header looks like this:
      #
      #     Authorization: Token token="abc", nonce="def"
      #
      # Then the returned token is `"abc"`, and the options are `{nonce: "def"}`.
      #
      # Returns an `Array` of `[String, Hash]` if a token is present. Returns `nil` if
      # no token is found.
      #
      # #### Parameters
      #
      # *   `request` - ActionDispatch::Request instance with the current headers.
      #
      def token_and_options(request)
        authorization_request = request.authorization.to_s
        if authorization_request[TOKEN_REGEX]
          params = token_params_from authorization_request
          [params.shift[1], Hash[params].with_indifferent_access]
        end
      end

      def token_params_from(auth)
        rewrite_param_values params_array_from raw_params auth
      end

      # Takes `raw_params` and turns it into an array of parameters.
      def params_array_from(raw_params)
        raw_params.map { |param| param.split %r/=(.+)?/ }
      end

      # This removes the `"` characters wrapping the value.
      def rewrite_param_values(array_params)
        array_params.each { |param| (param[1] || +"").gsub! %r/^"|"$/, "" }
      end

      # This method takes an authorization body and splits up the key-value pairs by
      # the standardized `:`, `;`, or `\t` delimiters defined in
      # `AUTHN_PAIR_DELIMITERS`.
      def raw_params(auth)
        _raw_params = auth.sub(TOKEN_REGEX, "").split(AUTHN_PAIR_DELIMITERS).map(&:strip)
        _raw_params.reject!(&:empty?)

        if !_raw_params.first&.start_with?(TOKEN_KEY)
          _raw_params[0] = "#{TOKEN_KEY}#{_raw_params.first}"
        end

        _raw_params
      end

      # Encodes the given token and options into an Authorization header value.
      #
      # Returns String.
      #
      # #### Parameters
      #
      # *   `token` - String token.
      # *   `options` - Optional Hash of the options.
      #
      def encode_credentials(token, options = {})
        values = ["#{TOKEN_KEY}#{token.to_s.inspect}"] + options.map do |key, value|
          "#{key}=#{value.to_s.inspect}"
        end
        "Token #{values * ", "}"
      end

      # Sets a WWW-Authenticate header to let the client know a token is desired.
      #
      # Returns nothing.
      #
      # #### Parameters
      #
      # *   `controller` - ActionController::Base instance for the outgoing response.
      # *   `realm` - String realm to use in the header.
      #
      def authentication_request(controller, realm, message = nil)
        message ||= "HTTP Token: Access denied.\n"
        controller.headers["WWW-Authenticate"] = %(Token realm="#{realm.tr('"', "")}")
        controller.__send__ :render, plain: message, status: :unauthorized
      end
    end
  end
end
