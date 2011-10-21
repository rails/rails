require 'action_dispatch/middleware/session/abstract_store'
require 'rack/session/memcache'

module ActionDispatch
  module Session
    # Session store that uses an ActiveSupport::Cache::Store to store the sessions. This store is most useful
    # if you don't store critical data in your sessions and you don't need them to live for extended periods
    # of time.
    class CacheStore < AbstractStore
      # Create a new store. The cache to use can be passed in the <tt>:cache</tt> option. If it is
      # not specified, <tt>Rails.cache</tt> will be used.
      def initialize(app, options = {})
        @cache = options[:cache] || Rails.cache
        options[:expire_after] ||= @cache.options[:expires_in]
        super
      end

      # Get a session from the cache.
      def get_session(env, sid)
        sid ||= generate_sid
        session = @cache.read(cache_key(sid))
        session ||= {}
        [sid, session]
      end

      # Set a session in the cache.
      def set_session(env, sid, session, options)
        key = cache_key(sid)
        if session
          @cache.write(key, session, :expires_in => options[:expire_after])
        else
          @cache.delete(key)
        end
        sid
      end

      # Remove a session from the cache.
      def destroy_session(env, sid, options)
        @cache.delete(cache_key(sid))
        generate_sid
      end

      private
        # Turn the session id into a cache key.
        def cache_key(sid)
          "_session_id:#{sid}"
        end
    end
  end
end
