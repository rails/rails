module ActionDispatch
  module Session
    class MemCacheStore < AbstractStore
      def initialize(app, options = {})
        require 'memcache'

        # Support old :expires option
        options[:expire_after] ||= options[:expires]

        super

        @default_options = {
          :namespace => 'rack:session',
          :memcache_server => 'localhost:11211'
        }.merge(@default_options)

        @pool = options[:cache] || MemCache.new(@default_options[:memcache_server], @default_options)
        unless @pool.servers.any? { |s| s.alive? }
          raise "#{self} unable to find server during initialization."
        end
        @mutex = Mutex.new

        super
      end

      private
        def get_session(env, sid)
          sid ||= generate_sid
          begin
            session = @pool.get(sid) || {}
          rescue MemCache::MemCacheError, Errno::ECONNREFUSED
            session = {}
          end
          [sid, session]
        end

        def set_session(env, sid, session_data)
          options = env['rack.session.options']
          expiry  = options[:expire_after] || 0
          @pool.set(sid, session_data, expiry)
          sid
        rescue MemCache::MemCacheError, Errno::ECONNREFUSED
          false
        end

        def destroy(env)
          if sid = current_session_id(env)
            @pool.delete(sid)
          end
        rescue MemCache::MemCacheError, Errno::ECONNREFUSED
          false
        end

    end
  end
end
