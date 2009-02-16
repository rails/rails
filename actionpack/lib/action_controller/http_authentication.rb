module ActionController
  module HttpAuthentication
    # Makes it dead easy to do HTTP Basic authentication.
    #
    # Simple Basic example:
    #
    #   class PostsController < ApplicationController
    #     USER_NAME, PASSWORD = "dhh", "secret"
    #
    #     before_filter :authenticate, :except => [ :index ]
    #
    #     def index
    #       render :text => "Everyone can see me!"
    #     end
    #
    #     def edit
    #       render :text => "I'm only accessible if you know the password"
    #     end
    #
    #     private
    #       def authenticate
    #         authenticate_or_request_with_http_basic do |user_name, password|
    #           user_name == USER_NAME && password == PASSWORD
    #         end
    #       end
    #   end
    #
    #
    # Here is a more advanced Basic example where only Atom feeds and the XML API is protected by HTTP authentication,
    # the regular HTML interface is protected by a session approach:
    #
    #   class ApplicationController < ActionController::Base
    #     before_filter :set_account, :authenticate
    #
    #     protected
    #       def set_account
    #         @account = Account.find_by_url_name(request.subdomains.first)
    #       end
    #
    #       def authenticate
    #         case request.format
    #         when Mime::XML, Mime::ATOM
    #           if user = authenticate_with_http_basic { |u, p| @account.users.authenticate(u, p) }
    #             @current_user = user
    #           else
    #             request_http_basic_authentication
    #           end
    #         else
    #           if session_authenticated?
    #             @current_user = @account.users.find(session[:authenticated][:user_id])
    #           else
    #             redirect_to(login_url) and return false
    #           end
    #         end
    #       end
    #   end
    #
    # In your integration tests, you can do something like this:
    #
    #   def test_access_granted_from_xml
    #     get(
    #       "/notes/1.xml", nil,
    #       :authorization => ActionController::HttpAuthentication::Basic.encode_credentials(users(:dhh).name, users(:dhh).password)
    #     )
    #
    #     assert_equal 200, status
    #   end
    #
    # Simple Digest example:
    #
    #   class PostsController < ApplicationController
    #     USERS = {"dhh" => "secret"}
    #
    #     before_filter :authenticate, :except => [:index]
    #
    #     def index
    #       render :text => "Everyone can see me!"
    #     end
    #
    #     def edit
    #       render :text => "I'm only accessible if you know the password"
    #     end
    #
    #     private
    #       def authenticate
    #         authenticate_or_request_with_http_digest(realm) do |username|
    #           USERS[username]
    #         end
    #       end
    #   end
    #
    # NOTE: The +authenticate_or_request_with_http_digest+ block must return the user's password so the framework can appropriately
    #       hash it to check the user's credentials. Returning +nil+ will cause authentication to fail.
    #
    # On shared hosts, Apache sometimes doesn't pass authentication headers to
    # FCGI instances. If your environment matches this description and you cannot
    # authenticate, try this rule in your Apache setup:
    #
    #   RewriteRule ^(.*)$ dispatch.fcgi [E=X-HTTP_AUTHORIZATION:%{HTTP:Authorization},QSA,L]
    module Basic
      extend self

      module ControllerMethods
        def authenticate_or_request_with_http_basic(realm = "Application", &login_procedure)
          authenticate_with_http_basic(&login_procedure) || request_http_basic_authentication(realm)
        end

        def authenticate_with_http_basic(&login_procedure)
          HttpAuthentication::Basic.authenticate(self, &login_procedure)
        end

        def request_http_basic_authentication(realm = "Application")
          HttpAuthentication::Basic.authentication_request(self, realm)
        end
      end

      def authenticate(controller, &login_procedure)
        unless authorization(controller.request).blank?
          login_procedure.call(*user_name_and_password(controller.request))
        end
      end

      def user_name_and_password(request)
        decode_credentials(request).split(/:/, 2)
      end

      def authorization(request)
        request.env['HTTP_AUTHORIZATION']   ||
        request.env['X-HTTP_AUTHORIZATION'] ||
        request.env['X_HTTP_AUTHORIZATION'] ||
        request.env['REDIRECT_X_HTTP_AUTHORIZATION']
      end

      def decode_credentials(request)
        ActiveSupport::Base64.decode64(authorization(request).split.last || '')
      end

      def encode_credentials(user_name, password)
        "Basic #{ActiveSupport::Base64.encode64("#{user_name}:#{password}")}"
      end

      def authentication_request(controller, realm)
        controller.headers["WWW-Authenticate"] = %(Basic realm="#{realm.gsub(/"/, "")}")
        controller.__send__ :render, :text => "HTTP Basic: Access denied.\n", :status => :unauthorized
      end
    end

    module Digest
      extend self

      module ControllerMethods
        def authenticate_or_request_with_http_digest(realm = "Application", &password_procedure)
          authenticate_with_http_digest(realm, &password_procedure) || request_http_digest_authentication(realm)
        end

        # Authenticate with HTTP Digest, returns true or false
        def authenticate_with_http_digest(realm = "Application", &password_procedure)
          HttpAuthentication::Digest.authenticate(self, realm, &password_procedure)
        end

        # Render output including the HTTP Digest authentication header
        def request_http_digest_authentication(realm = "Application", message = nil)
          HttpAuthentication::Digest.authentication_request(self, realm, message)
        end
      end

      # Returns false on a valid response, true otherwise
      def authenticate(controller, realm, &password_procedure)
        authorization(controller.request) && validate_digest_response(controller.request, realm, &password_procedure)
      end

      def authorization(request)
        request.env['HTTP_AUTHORIZATION']   ||
        request.env['X-HTTP_AUTHORIZATION'] ||
        request.env['X_HTTP_AUTHORIZATION'] ||
        request.env['REDIRECT_X_HTTP_AUTHORIZATION']
      end

      # Raises error unless the request credentials response value matches the expected value.
      def validate_digest_response(request, realm, &password_procedure)
        credentials = decode_credentials_header(request)
        valid_nonce = validate_nonce(request, credentials[:nonce])

        if valid_nonce && realm == credentials[:realm] && opaque(request.session.session_id) == credentials[:opaque]
          password = password_procedure.call(credentials[:username])
          expected = expected_response(request.env['REQUEST_METHOD'], credentials[:uri], credentials, password)
          expected == credentials[:response]
        end
      end

      # Returns the expected response for a request of +http_method+ to +uri+ with the decoded +credentials+ and the expected +password+
      def expected_response(http_method, uri, credentials, password)
        ha1 = ::Digest::MD5.hexdigest([credentials[:username], credentials[:realm], password].join(':'))
        ha2 = ::Digest::MD5.hexdigest([http_method.to_s.upcase, uri].join(':'))
        ::Digest::MD5.hexdigest([ha1, credentials[:nonce], credentials[:nc], credentials[:cnonce], credentials[:qop], ha2].join(':'))
      end

      def encode_credentials(http_method, credentials, password)
        credentials[:response] = expected_response(http_method, credentials[:uri], credentials, password)
        "Digest " + credentials.sort_by {|x| x[0].to_s }.inject([]) {|a, v| a << "#{v[0]}='#{v[1]}'" }.join(', ')
      end

      def decode_credentials_header(request)
        decode_credentials(authorization(request))
      end

      def decode_credentials(header)
        header.to_s.gsub(/^Digest\s+/,'').split(',').inject({}) do |hash, pair|
          key, value = pair.split('=', 2)
          hash[key.strip.to_sym] = value.to_s.gsub(/^"|"$/,'').gsub(/'/, '')
          hash
        end
      end

      def authentication_header(controller, realm)
        session_id = controller.request.session.session_id
        controller.headers["WWW-Authenticate"] = %(Digest realm="#{realm}", qop="auth", algorithm=MD5, nonce="#{nonce(session_id)}", opaque="#{opaque(session_id)}")
      end

      def authentication_request(controller, realm, message = nil)
        message ||= "HTTP Digest: Access denied.\n"
        authentication_header(controller, realm)
        controller.__send__ :render, :text => message, :status => :unauthorized
      end

      # Uses an MD5 digest based on time to generate a value to be used only once.
      #
      # A server-specified data string which should be uniquely generated each time a 401 response is made.
      # It is recommended that this string be base64 or hexadecimal data.
      # Specifically, since the string is passed in the header lines as a quoted string, the double-quote character is not allowed.
      #
      # The contents of the nonce are implementation dependent.
      # The quality of the implementation depends on a good choice.
      # A nonce might, for example, be constructed as the base 64 encoding of
      #
      # => time-stamp H(time-stamp ":" ETag ":" private-key)
      #
      # where time-stamp is a server-generated time or other non-repeating value,
      # ETag is the value of the HTTP ETag header associated with the requested entity,
      # and private-key is data known only to the server.
      # With a nonce of this form a server would recalculate the hash portion after receiving the client authentication header and
      # reject the request if it did not match the nonce from that header or
      # if the time-stamp value is not recent enough. In this way the server can limit the time of the nonce's validity.
      # The inclusion of the ETag prevents a replay request for an updated version of the resource.
      # (Note: including the IP address of the client in the nonce would appear to offer the server the ability
      # to limit the reuse of the nonce to the same client that originally got it.
      # However, that would break proxy farms, where requests from a single user often go through different proxies in the farm.
      # Also, IP address spoofing is not that hard.)
      #
      # An implementation might choose not to accept a previously used nonce or a previously used digest, in order to
      # protect against a replay attack. Or, an implementation might choose to use one-time nonces or digests for
      # POST or PUT requests and a time-stamp for GET requests. For more details on the issues involved see Section 4
      # of this document.
      #
      # The nonce is opaque to the client.
      def nonce(session_id, time = Time.now)
        t = time.to_i
        hashed = [t, session_id]
        digest = ::Digest::MD5.hexdigest(hashed.join(":"))
        Base64.encode64("#{t}:#{digest}").gsub("\n", '')
      end

      def validate_nonce(request, value)
        t = Base64.decode64(value).split(":").first.to_i
        nonce(request.session.session_id, t) == value && (t - Time.now.to_i).abs <= 10 * 60
      end

      # Opaque based on digest of session_id
      def opaque(session_id)
        Base64.encode64(::Digest::MD5::hexdigest(session_id)).gsub("\n", '')
      end
    end
  end
end
