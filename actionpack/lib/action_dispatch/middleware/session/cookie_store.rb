require 'action_dispatch/middleware/cookies'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/blank'

module ActionDispatch
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
      DEFAULT_OPTIONS = {
        :key          => '_session_id',
        :domain       => nil,
        :path         => "/",
        :expire_after => nil,
        :httponly     => true
      }.freeze

      class OptionsHash < Hash
        def initialize(by, env, default_options)
          @session_data = env[CookieStore::ENV_SESSION_KEY]
          merge!(default_options)
        end

        def [](key)
          key == :id ? @session_data[:session_id] : super(key)
        end
      end

      ENV_SESSION_KEY = "rack.session".freeze
      ENV_SESSION_OPTIONS_KEY = "rack.session.options".freeze

      def initialize(app, options = {})
        # Process legacy CGI options
        # TODO Refactor and deprecate me
        options = options.symbolize_keys

        if options.has_key?(:session_path)
          options[:path] = options.delete(:session_path)
        end
        if options.has_key?(:session_key)
          options[:key] = options.delete(:session_key)
        end
        if options.has_key?(:session_http_only)
          options[:httponly] = options.delete(:session_http_only)
        end

        @app = app

        # The session_key option is required.
        ensure_session_key(options[:key])
        @key = options.delete(:key).freeze

        @default_options = DEFAULT_OPTIONS.merge(options).freeze
        freeze
      end

      def call(env)
        env[ENV_SESSION_KEY] = AbstractStore::SessionHash.new(self, env)
        env[ENV_SESSION_OPTIONS_KEY] = OptionsHash.new(self, env, @default_options)

        status, headers, body = @app.call(env)

        session_data = env[ENV_SESSION_KEY]
        options = env[ENV_SESSION_OPTIONS_KEY]

        if !session_data.is_a?(AbstractStore::SessionHash) || session_data.send(:loaded?) || options[:expire_after]
          session_data.send(:load!) if session_data.is_a?(AbstractStore::SessionHash) && !session_data.send(:loaded?)
          session_data = persistent_session_id!(session_data.to_hash)

          cookie = { :value => session_data }
          unless options[:expire_after].nil?
            cookie[:expires] = Time.now + options.delete(:expire_after)
          end

          request = ActionDispatch::Request.new(env)
          request.cookie_jar.signed[@key] = cookie.merge!(options)
        end

        [status, headers, body]
      end

      private

        def load_session(env)
          request = ActionDispatch::Request.new(env)
          data = request.cookie_jar.signed[@key]
          data = persistent_session_id!(data || {})
          data.stringify_keys!
          [data["session_id"], data]
        end

        def generate_sid
          ActiveSupport::SecureRandom.hex(16)
        end

        def ensure_session_key(key)
          if key.blank?
            raise ArgumentError, 'A key is required to write a ' +
              'cookie containing the session data. Use ' +
              'config.session_store :cookie_store, { :key => ' +
              '"_myapp_session" } in config/application.rb'
          end
        end

        def persistent_session_id!(data)
          (data ||= {}).merge!(inject_persistent_session_id(data))
        end

        def inject_persistent_session_id(data)
          requires_session_id?(data) ? { "session_id" => generate_sid } : {}
        end

        def requires_session_id?(data)
          if data
            data.respond_to?(:key?) && !data.key?("session_id")
          else
            true
          end
        end
    end
  end
end
