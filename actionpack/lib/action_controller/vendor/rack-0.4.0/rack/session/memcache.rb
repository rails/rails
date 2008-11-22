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
      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge({
        :namespace => 'rack:session',
        :memcache_server => 'localhost:11211'
      })

      def initialize(app, options={})
        super
        @pool = MemCache.new @default_options[:memcache_server], @default_options
        unless @pool.servers.any?{|s|s.alive?}
          raise "#{self} unable to find server during initialization."
        end
        @mutex = Mutex.new
      end

      private

      def get_session(env, sid)
        session = sid && @pool.get(sid)
        unless session and session.is_a?(Hash)
          session = {}
          lc = 0
          @mutex.synchronize do
            begin
              raise RuntimeError, 'Unique id finding looping excessively' if (lc+=1) > 1000
              sid = "%08x" % rand(0xffffffff)
              ret = @pool.add(sid, session)
            end until /^STORED/ =~ ret
          end
        end
        class << session
          @deleted = []
          def delete key
            (@deleted||=[]) << key
            super
          end
        end
        [sid, session]
      rescue MemCache::MemCacheError, Errno::ECONNREFUSED # MemCache server cannot be contacted
        warn "#{self} is unable to find server."
        warn $!.inspect
        return [ nil, {} ]
      end

      def set_session(env, sid)
        session = env['rack.session']
        options = env['rack.session.options']
        expiry  = options[:expire_after] || 0
        o, s = @mutex.synchronize do
          old_session = @pool.get(sid)
          unless old_session.is_a?(Hash)
            warn 'Session not properly initialized.' if $DEBUG
            old_session = {}
            @pool.add sid, old_session, expiry
          end
          session.instance_eval do
            @deleted.each{|k| old_session.delete(k) } if defined? @deleted
          end
          @pool.set sid, old_session.merge(session), expiry
          [old_session, session]
        end
        s.each do |k,v|
          next unless o.has_key?(k) and v != o[k]
          warn "session value assignment collision at #{k.inspect}:"+
            "\n\t#{o[k].inspect}\n\t#{v.inspect}"
        end if $DEBUG and env['rack.multithread']
        return true
      rescue MemCache::MemCacheError, Errno::ECONNREFUSED # MemCache server cannot be contacted
        warn "#{self} is unable to find server."
        warn $!.inspect
        return false
      end
    end
  end
end
