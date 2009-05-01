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
    # The :drop option is available in rack.session.options if you with to
    # explicitly remove the session from the session cache.
    #
    # Example:
    #   myapp = MyRackApp.new
    #   sessioned = Rack::Session::Pool.new(myapp,
    #     :domain => 'foo.com',
    #     :expire_after => 2592000
    #   )
    #   Rack::Handler::WEBrick.run sessioned

    class Pool < Abstract::ID
      attr_reader :mutex, :pool
      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge :drop => false

      def initialize(app, options={})
        super
        @pool = Hash.new
        @mutex = Mutex.new
      end

      def generate_sid
        loop do
          sid = super
          break sid unless @pool.key? sid
        end
      end

      def get_session(env, sid)
        session = @pool[sid] if sid
        @mutex.lock if env['rack.multithread']
        unless sid and session
          env['rack.errors'].puts("Session '#{sid.inspect}' not found, initializing...") if $VERBOSE and not sid.nil?
          session = {}
          sid = generate_sid
          @pool.store sid, session
        end
        session.instance_variable_set('@old', {}.merge(session))
        return [sid, session]
      ensure
        @mutex.unlock if env['rack.multithread']
      end

      def set_session(env, session_id, new_session, options)
        @mutex.lock if env['rack.multithread']
        session = @pool[session_id]
        if options[:renew] or options[:drop]
          @pool.delete session_id
          return false if options[:drop]
          session_id = generate_sid
          @pool.store session_id, 0
        end
        old_session = new_session.instance_variable_get('@old') || {}
        session = merge_sessions session_id, old_session, new_session, session
        @pool.store session_id, session
        return session_id
      rescue
        warn "#{new_session.inspect} has been lost."
        warn $!.inspect
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
        warn "//@#{sid}: dropping #{delete*','}" if $DEBUG and not delete.empty?
        delete.each{|k| cur.delete k }

        update = new.keys.select{|k| new[k] != old[k] }
        warn "//@#{sid}: updating #{update*','}" if $DEBUG and not update.empty?
        update.each{|k| cur[k] = new[k] }

        cur
      end
    end
  end
end
