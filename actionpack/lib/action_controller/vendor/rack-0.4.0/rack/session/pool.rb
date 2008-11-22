# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net
# THANKS:
#   apeiros, for session id generation, expiry setup, and threadiness
#   sergio, threadiness and bugreps

require 'rack/session/abstract/id'
require 'thread'

module Rack
  module Session
    # Rack::Session::Pool provides simple cookie based session management.
    # Session data is stored in a hash held by @pool.
    # In the context of a multithreaded environment, sessions being
    # committed to the pool is done in a merging manner.
    #
    # Example:
    #   myapp = MyRackApp.new
    #   sessioned = Rack::Session::Pool.new(myapp,
    #     :key => 'rack.session',
    #     :domain => 'foo.com',
    #     :path => '/',
    #     :expire_after => 2592000
    #   )
    #   Rack::Handler::WEBrick.run sessioned

    class Pool < Abstract::ID
      attr_reader :mutex, :pool
      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.dup

      def initialize(app, options={})
        super
        @pool = Hash.new
        @mutex = Mutex.new
      end

      private

      def get_session(env, sid)
        session = @mutex.synchronize do
          unless sess = @pool[sid] and ((expires = sess[:expire_at]).nil? or expires > Time.now)
            @pool.delete_if{|k,v| expiry = v[:expire_at] and expiry < Time.now }
            begin
              sid = "%08x" % rand(0xffffffff)
            end while @pool.has_key?(sid)
          end
          @pool[sid] ||= {}
        end
        [sid, session]
      end

      def set_session(env, sid)
        options = env['rack.session.options']
        expiry = options[:expire_after] && options[:at]+options[:expire_after]
        @mutex.synchronize do
          old_session = @pool[sid]
          old_session[:expire_at] = expiry if expiry
          session = old_session.merge(env['rack.session'])
          @pool[sid] = session
          session.each do |k,v|
            next unless old_session.has_key?(k) and v != old_session[k]
            warn "session value assignment collision at #{k}: #{old_session[k]} <- #{v}"
          end if $DEBUG and env['rack.multithread']
        end
        return true
      rescue
        warn "#{self} is unable to find server."
        warn "#{env['rack.session'].inspect} has been lost."
        warn $!.inspect
        return false
      end
    end
  end
end
