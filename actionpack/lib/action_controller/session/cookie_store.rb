module ActionController
  module Session
    # This cookie-based session store is the Rails default. Sessions typically
    # contain at most a user_id and flash message; both fit within the 4K cookie
    # size limit. Cookie-based sessions are dramatically faster than the
    # alternatives.
    #
    # If you have more than 4K of session data or don't want your data to be
    # visible to the user, pick another session store.
    #
    # CookieOverflow is raised if you attempt to store more than 4K of data.
    #
    # A message digest is included with the cookie to ensure data integrity:
    # a user cannot alter his +user_id+ without knowing the secret key
    # included in the hash. New apps are generated with a pregenerated secret
    # in config/environment.rb. Set your own for old apps you're upgrading.
    #
    # Session options:
    #
    # * <tt>:secret</tt>: An application-wide key string or block returning a
    #   string called per generated digest. The block is called with the
    #   CGI::Session instance as an argument. It's important that the secret
    #   is not vulnerable to a dictionary attack. Therefore, you should choose
    #   a secret consisting of random numbers and letters and more than 30
    #   characters. Examples:
    #
    #     :secret => '449fe2e7daee471bffae2fd8dc02313d'
    #     :secret => Proc.new { User.current_user.secret_key }
    #
    # * <tt>:digest</tt>: The message digest algorithm used to verify session
    #   integrity defaults to 'SHA1' but may be any digest provided by OpenSSL,
    #   such as 'MD5', 'RIPEMD160', 'SHA256', etc.
    #
    # To generate a secret key for an existing application, run
    # "rake secret" and set the key in config/environment.rb.
    #
    # Note that changing digest or secret invalidates all existing sessions!
    class CookieStore
      include AbstractStore::SessionUtils
      
      # Cookies can typically store 4096 bytes.
      MAX = 4096
      SECRET_MIN_LENGTH = 30 # characters

      DEFAULT_OPTIONS = {
        :key          => '_session_id',
        :domain       => nil,
        :path         => "/",
        :expire_after => nil,
        :httponly     => true
      }.freeze

      ENV_SESSION_KEY = "rack.session".freeze
      ENV_SESSION_OPTIONS_KEY = "rack.session.options".freeze
      HTTP_SET_COOKIE = "Set-Cookie".freeze

      # Raised when storing more than 4K of session data.
      class CookieOverflow < StandardError; end

      def initialize(app, options = {})
        # Process legacy CGI options
        options = options.symbolize_keys
        if options.has_key?(:session_path)
          ActiveSupport::Deprecation.warn "Giving :session_path to SessionStore is deprecated, " <<
            "please use :path instead", caller
          options[:path] = options.delete(:session_path)
        end
        if options.has_key?(:session_key)
          ActiveSupport::Deprecation.warn "Giving :session_key to SessionStore is deprecated, " <<
            "please use :key instead", caller
          options[:key] = options.delete(:session_key)
        end
        if options.has_key?(:session_http_only)
          ActiveSupport::Deprecation.warn "Giving :session_http_only to SessionStore is deprecated, " <<
            "please use :httponly instead", caller
          options[:httponly] = options.delete(:session_http_only)
        end

        @app = app

        # The session_key option is required.
        ensure_session_key(options[:key])
        @key = options.delete(:key).freeze

        # The secret option is required.
        ensure_secret_secure(options[:secret])
        @secret = options.delete(:secret).freeze

        @digest = options.delete(:digest) || 'SHA1'
        @verifier = verifier_for(@secret, @digest)

        @default_options = DEFAULT_OPTIONS.merge(options).freeze

        freeze
      end

      def call(env)
        prepare!(env)
        
        status, headers, body = @app.call(env)

        session_data = env[ENV_SESSION_KEY]
        options = env[ENV_SESSION_OPTIONS_KEY]
        request = ActionController::Request.new(env)
        
        if !(options[:secure] && !request.ssl?) && (!session_data.is_a?(AbstractStore::SessionHash) || session_data.loaded? || options[:expire_after])
          session_data.send(:load!) if session_data.is_a?(AbstractStore::SessionHash) && !session_data.loaded?

          persistent_session_id!(session_data)
          session_data = marshal(session_data.to_hash)

          raise CookieOverflow if session_data.size > MAX
          cookie = Hash.new
          cookie[:value] = session_data
          unless options[:expire_after].nil?
            cookie[:expires] = Time.now + options[:expire_after]
          end

          cookie = build_cookie(@key, cookie.merge(options))
          headers[HTTP_SET_COOKIE] = [] if headers[HTTP_SET_COOKIE].blank?
          headers[HTTP_SET_COOKIE] << cookie
        end

        [status, headers, body]
      end

      private
      
        def prepare!(env)
          env[ENV_SESSION_KEY] = AbstractStore::SessionHash.new(self, env)
          env[ENV_SESSION_OPTIONS_KEY] = AbstractStore::OptionsHash.new(self, env, @default_options)
        end
      
        # Should be in Rack::Utils soon
        def build_cookie(key, value)
          case value
          when Hash
            domain  = "; domain="  + value[:domain] if value[:domain]
            path    = "; path="    + value[:path]   if value[:path]
            # According to RFC 2109, we need dashes here.
            # N.B.: cgi.rb uses spaces...
            expires = "; expires=" + value[:expires].clone.gmtime.
              strftime("%a, %d-%b-%Y %H:%M:%S GMT") if value[:expires]
            secure = "; secure" if value[:secure]
            httponly = "; HttpOnly" if value[:httponly]
            value = value[:value]
          end
          value = [value] unless Array === value
          cookie = Rack::Utils.escape(key) + "=" +
            value.map { |v| Rack::Utils.escape(v) }.join("&") +
            "#{domain}#{path}#{expires}#{secure}#{httponly}"
        end

        def load_session(env)
          data = unpacked_cookie_data(env)
          data = persistent_session_id!(data)
          [data[:session_id], data]
        end
        
        def extract_session_id(env)
          if data = unpacked_cookie_data(env)
            persistent_session_id!(data) unless data.empty?
            data[:session_id]
          else
            nil
          end
        end

        def current_session_id(env)
          env[ENV_SESSION_OPTIONS_KEY][:id]
        end

        def exists?(env)
          current_session_id(env).present?
        end

        def unpacked_cookie_data(env)
          env["action_dispatch.request.unsigned_session_cookie"] ||= begin
            stale_session_check! do
              request = Rack::Request.new(env)
              session_data = request.cookies[@key]
              unmarshal(session_data) || {}
            end
          end
        end

        # Marshal a session hash into safe cookie data. Include an integrity hash.
        def marshal(session)
          @verifier.generate(session)
        end

        # Unmarshal cookie data to a hash and verify its integrity.
        def unmarshal(cookie)
          @verifier.verify(cookie) if cookie
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end

        def ensure_session_key(key)
          if key.blank?
            raise ArgumentError, 'A key is required to write a ' +
              'cookie containing the session data. Use ' +
              'config.action_controller.session = { :key => ' +
              '"_myapp_session", :secret => "some secret phrase" } in ' +
              'config/environment.rb'
          end
        end

        # To prevent users from using something insecure like "Password" we make sure that the
        # secret they've provided is at least 30 characters in length.
        def ensure_secret_secure(secret)
          # There's no way we can do this check if they've provided a proc for the
          # secret.
          return true if secret.is_a?(Proc)

          if secret.blank?
            raise ArgumentError, "A secret is required to generate an " +
              "integrity hash for cookie session data. Use " +
              "config.action_controller.session = { :key => " +
              "\"_myapp_session\", :secret => \"some secret phrase of at " +
              "least #{SECRET_MIN_LENGTH} characters\" } " +
              "in config/environment.rb"
          end

          if secret.length < SECRET_MIN_LENGTH
            raise ArgumentError, "Secret should be something secure, " +
              "like \"#{ActiveSupport::SecureRandom.hex(16)}\".  The value you " +
              "provided, \"#{secret}\", is shorter than the minimum length " +
              "of #{SECRET_MIN_LENGTH} characters"
          end
        end

        def verifier_for(secret, digest)
          key = secret.respond_to?(:call) ? secret.call : secret
          ActiveSupport::MessageVerifier.new(key, digest)
        end

        def generate_sid
          ActiveSupport::SecureRandom.hex(16)
        end

        def destroy(env)
          # session data is stored on client; nothing to do here
        end

        def persistent_session_id!(data)
          (data ||= {}).merge!(inject_persistent_session_id(data))
        end

        def inject_persistent_session_id(data)
          requires_session_id?(data) ? { :session_id => generate_sid } : {}
        end

        def requires_session_id?(data)
          if data
            data.respond_to?(:key?) && !data.key?(:session_id)
          else
            true
          end
        end
    end
  end
end
