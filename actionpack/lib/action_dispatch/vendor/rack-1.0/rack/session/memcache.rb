# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

require 'rack/session/abstract/id'
require 'memcache'

module Rack
  module Session
    # Rack::Session::Memcache provides simple cookie based session management.
    # Session data is stored in memcached. The corresponding session key is
    # maintained in the cookie.
    # You may treat Session::Memcache as you would Session::Pool with the
    # following caveats.
    #
    # * Setting :expire_after to 0 would note to the Memcache server to hang
    #   onto the session data until it would drop it according to it's own
    #   specifications. However, the cookie sent to the client would expire
    #   immediately.
    #
    # Note that memcache does drop data before it may be listed to expire. For
    # a full description of behaviour, please see memcache's documentation.

    class Memcache < Abstract::ID
      attr_reader :mutex, :pool
      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge \
        :namespace => 'rack:session',
        :memcache_server => 'localhost:11211'

      def initialize(app, options={})
        super

        @mutex = Mutex.new
        @pool = MemCache.
          new @default_options[:memcache_server], @default_options
        raise 'No memcache servers' unless @pool.servers.any?{|s|s.alive?}
      end

      def generate_sid
        loop do
          sid = super
          break sid unless @pool.get(sid, true)
        end
      end

      def get_session(env, sid)
        session = @pool.get(sid) if sid
        @mutex.lock if env['rack.multithread']
        unless sid and session
          env['rack.errors'].puts("Session '#{sid.inspect}' not found, initializing...") if $VERBOSE and not sid.nil?
          session = {}
          sid = generate_sid
          ret = @pool.add sid, session
          raise "Session collision on '#{sid.inspect}'" unless /^STORED/ =~ ret
        end
        session.instance_variable_set('@old', {}.merge(session))
        return [sid, session]
      rescue MemCache::MemCacheError, Errno::ECONNREFUSED # MemCache server cannot be contacted
        warn "#{self} is unable to find server."
        warn $!.inspect
        return [ nil, {} ]
      ensure
        @mutex.unlock if env['rack.multithread']
      end

      def set_session(env, session_id, new_session, options)
        expiry = options[:expire_after]
        expiry = expiry.nil? ? 0 : expiry + 1

        @mutex.lock if env['rack.multithread']
        session = @pool.get(session_id) || {}
        if options[:renew] or options[:drop]
          @pool.delete session_id
          return false if options[:drop]
          session_id = generate_sid
          @pool.add session_id, 0 # so we don't worry about cache miss on #set
        end
        old_session = new_session.instance_variable_get('@old') || {}
        session = merge_sessions session_id, old_session, new_session, session
        @pool.set session_id, session, expiry
        return session_id
      rescue MemCache::MemCacheError, Errno::ECONNREFUSED # MemCache server cannot be contacted
        warn "#{self} is unable to find server."
        warn $!.inspect
        return false
      ensure
        @mutex.unlock if env['rack.multithread']
      end

      private

      def merge_sessions sid, old, new, cur=nil
        cur ||= {}
        unless Hash === old and Hash === new
          warn 'Bad old or new sessions provided.'
          return cur
        end

        delete = old.keys - new.keys
        warn "//@#{sid}: delete #{delete*','}" if $VERBOSE and not delete.empty?
        delete.each{|k| cur.delete k }

        update = new.keys.select{|k| new[k] != old[k] }
        warn "//@#{sid}: update #{update*','}" if $VERBOSE and not update.empty?
        update.each{|k| cur[k] = new[k] }

        cur
      end
    end
  end
end
