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
    # * <tt>:domain</tt>: Restrict the session cookie to certain domain level.
    #   If you use a schema like www.example.com and wants to share session 
    #   with user.example.com set <tt>:domain</tt> to <tt>:all</tt>
    #     
    #     :domain => nil  # Does not sets cookie domain. (default)
    #     :domain => :all # Allow the cookie for the top most level
    #                       domain and subdomains.
    #
    # To generate a secret key for an existing application, run
    # "rake secret" and set the key in config/environment.rb.
    #
    # Note that changing digest or secret invalidates all existing sessions!
    class CookieStore < AbstractStore
      class OptionsHash < Hash
        def initialize(by, env, default_options)
          @session_data = env[AbstractStore::ENV_SESSION_KEY]
          merge!(default_options)
        end

        def [](key)
          key == :id ? @session_data[:session_id] : super(key)
        end
      end

      def initialize(app, options = {})
        super(app, options.merge!(:cookie_only => true))
        freeze
      end

      private

        def prepare!(env)
          env[ENV_SESSION_KEY] = SessionHash.new(self, env)
          env[ENV_SESSION_OPTIONS_KEY] = OptionsHash.new(self, env, @default_options)
        end

        def load_session(env)
          request = ActionDispatch::Request.new(env)
          data = request.cookie_jar.signed[@key]
          data = persistent_session_id!(data)
          data.stringify_keys!
          [data["session_id"], data]
        end

        def set_cookie(request, options)
          request.cookie_jar.signed[@key] = options
        end

        def set_session(env, sid, session_data)
          persistent_session_id!(session_data, sid)
        end

        def persistent_session_id!(data, sid=nil)
          data ||= {}
          data["session_id"] ||= sid || generate_sid
          data
        end
    end
  end
end
