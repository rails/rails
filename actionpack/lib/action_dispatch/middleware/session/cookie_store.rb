require 'active_support/core_ext/hash/keys'
require 'action_dispatch/middleware/session/abstract_store'
require 'rack/session/cookie'

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
    #   characters.
    #
    #     secret: '449fe2e7daee471bffae2fd8dc02313d'
    #     secret: Proc.new { User.current_user.secret_key }
    #
    # * <tt>:digest</tt>: The message digest algorithm used to verify session
    #   integrity defaults to 'SHA1' but may be any digest provided by OpenSSL,
    #   such as 'MD5', 'RIPEMD160', 'SHA256', etc.
    #
    # To generate a secret key for an existing application, run
    # "rake secret" and set the key in config/initializers/secret_token.rb.
    #
    # Note that changing digest or secret invalidates all existing sessions!
    class CookieStore < Rack::Session::Cookie
      include Compatibility
      include StaleSessionCheck
      include SessionObject

      # Override rack's method
      def destroy_session(env, session_id, options)
        new_sid = super
        # Reset hash and Assign the new session id
        env["action_dispatch.request.unsigned_session_cookie"] = new_sid ? { "session_id" => new_sid } : {}
        new_sid
      end

      private

      def unpacked_cookie_data(env)
        env["action_dispatch.request.unsigned_session_cookie"] ||= begin
          stale_session_check! do
            if data = get_cookie(env)
              data.stringify_keys!
            end
            data || {}
          end
        end
      end

      def set_session(env, sid, session_data, options)
        session_data["session_id"] = sid
        session_data
      end

      def set_cookie(env, session_id, cookie)
        cookie_jar(env)[@key] = cookie
      end

      def get_cookie(env)
        cookie_jar(env)[@key]
      end

      def cookie_jar(env)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar.signed
      end
    end

    class EncryptedCookieStore < CookieStore

      private

      def cookie_jar(env)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar.encrypted
      end
    end

    # This cookie store helps you upgrading apps that use +CookieStore+ to the new default +EncryptedCookieStore+
    # To use this CookieStore set
    #
    # Myapp::Application.config.session_store :upgrade_signature_to_encryption_cookie_store, key: '_myapp_session'
    #
    # in your config/initializers/session_store.rb
    #
    # You will also need to add
    #
    # Myapp::Application.config.secret_key_base = 'some secret'
    #
    # in your config/initializers/secret_token.rb, but do not remove +Myapp::Application.config.secret_token = 'some secret'+
    class UpgradeSignatureToEncryptionCookieStore < EncryptedCookieStore
      private

      def get_cookie(env)
        signed_using_old_secret_cookie_jar(env)[@key] || cookie_jar(env)[@key]
      end

      def signed_using_old_secret_cookie_jar(env)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar.signed_using_old_secret
      end
    end
  end
end
