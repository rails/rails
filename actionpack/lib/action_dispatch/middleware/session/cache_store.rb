# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/middleware/session/abstract_store"

module ActionDispatch
  module Session
    # # Action Dispatch Session CacheStore
    #
    # A session store that uses an ActiveSupport::Cache::Store to store the
    # sessions. This store is most useful if you don't store critical data in your
    # sessions and you don't need them to live for extended periods of time.
    #
    # #### Options
    # *   `cache`         - The cache to use. If it is not specified, `Rails.cache`
    #     will be used.
    # *   `expire_after`  - The length of time a session will be stored before
    #     automatically expiring. By default, the `:expires_in` option of the cache
    #     is used.
    # *   `check_collisions`  - Check if newly generated session ids aren't already in use.
    #     If for some reason 128 bits of randomness aren't considered secure enough to avoid
    #     collisions, this option can be enabled to ensure newly generated ids aren't in use.
    #     By default, it is set to `false` to avoid additional cache write operations.
    #
    class CacheStore < AbstractSecureStore
      LOADED_SESSION_ID = "action_dispatch.session.cache_store.loaded_session_id" # :nodoc:

      def initialize(app, options = {})
        @cache = options[:cache] || Rails.cache
        options[:expire_after] ||= @cache.options[:expires_in]
        @check_collisions = options[:check_collisions] || false
        super
      end

      # Get a session from the cache.
      def find_session(req, sid)
        if sid && (session = get_session_with_fallback(sid))
          req.set_header(LOADED_SESSION_ID, sid.private_id)
        else
          sid, session = generate_sid, {}
        end
        [sid, session]
      end

      # Set a session in the cache.
      def write_session(req, sid, session, options)
        key = cache_key(sid.private_id)
        if session
          return false if destroyed_since_loaded?(req, sid)
          @cache.write(key, session, expires_in: options[:expire_after])
        else
          @cache.delete(key)
        end
        sid
      end

      # Remove a session from the cache.
      def delete_session(env, sid, options)
        @cache.delete(cache_key(sid.private_id))
        @cache.delete(cache_key(sid.public_id))
        generate_sid unless options[:drop]
      end

      private
        # Turn the session id into a cache key.
        def cache_key(id)
          "_session_id:#{id}"
        end

        def get_session_with_fallback(sid)
          @cache.read(cache_key(sid.private_id)) || @cache.read(cache_key(sid.public_id))
        end

        # Writing back a session that another request deleted, such as on logout,
        # would restore it.
        def destroyed_since_loaded?(req, sid)
          req.get_header(LOADED_SESSION_ID) == sid.private_id &&
            !exist_in_backend?(cache_key(sid.private_id)) &&
            !exist_in_backend?(cache_key(sid.public_id))
        end

        # The request-local cache still holds the entry this request loaded, so
        # a lookup through it cannot see a delete made by another request.
        def exist_in_backend?(key)
          if @cache.respond_to?(:with_local_cache)
            @cache.with_local_cache { @cache.exist?(key) }
          else
            @cache.exist?(key)
          end
        end

        def generate_sid
          if @check_collisions
            loop do
              sid = super
              key = cache_key(sid.private_id)
              break sid if @cache.write(key, {}, unless_exist: true, expires_in: default_options[:expire_after])
            end
          else
            super
          end
        end
    end
  end
end
