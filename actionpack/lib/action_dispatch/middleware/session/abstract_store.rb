require 'rack/utils'
require 'rack/request'
require 'rack/session/abstract/id'
require 'action_dispatch/middleware/cookies'
require 'active_support/core_ext/object/blank'

module ActionDispatch
  module Session
    class SessionRestoreError < StandardError #:nodoc:
      attr_reader :original_exception

      def initialize(const_error)
        @original_exception = const_error

        super("Session contains objects whose class definition isn't available.\n" +
          "Remember to require the classes for all objects kept in the session.\n" +
          "(Original exception: #{const_error.message} [#{const_error.class}])\n")
      end
    end

    module Compatibility
      def initialize(app, options = {})
        options[:key] ||= '_session_id'
        super
      end

      def generate_sid
        sid = SecureRandom.hex(16)
        sid.encode!('UTF-8')
        sid
      end

    protected

      def initialize_sid
        @default_options.delete(:sidbits)
        @default_options.delete(:secure_random)
      end
    end

    module StaleSessionCheck
      def load_session(env)
        stale_session_check! { super }
      end

      def extract_session_id(env)
        stale_session_check! { super }
      end

      def stale_session_check!
        yield
      rescue ArgumentError => argument_error
        if argument_error.message =~ %r{undefined class/module ([\w:]*\w)}
          begin
            # Note that the regexp does not allow $1 to end with a ':'
            $1.constantize
          rescue LoadError, NameError => e
            raise ActionDispatch::Session::SessionRestoreError, e, e.backtrace
          end
          retry
        else
          raise
        end
      end
    end

    class AbstractStore < Rack::Session::Abstract::ID
      include Compatibility
      include StaleSessionCheck

      ENV_SESSION_KEY         = Rack::Session::Abstract::ENV_SESSION_KEY # :nodoc:
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY # :nodoc:

      private

      def prepare_session(env)
        session_was                  = env[ENV_SESSION_KEY]
        env[ENV_SESSION_KEY]         = Request::Session.new(self, env)
        env[ENV_SESSION_OPTIONS_KEY] = Request::Session::Options.new(self, env, @default_options)
        env[ENV_SESSION_KEY].merge! session_was if session_was
      end

      def loaded_session?(session)
        !session.is_a?(Request::Session) || session.loaded?
      end

      def set_cookie(env, session_id, cookie)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar[key] = cookie
      end
    end
  end

  class Request
    # SessionHash is responsible to lazily load the session from store.
    class Session < Hash
      ENV_SESSION_KEY         = Rack::Session::Abstract::ENV_SESSION_KEY # :nodoc:
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY # :nodoc:

      class Options #:nodoc:
        def initialize(by, env, default_options)
          @by       = by
          @env      = env
          @delegate = default_options
        end

        def [](key)
          if key == :id
            @delegate.fetch(key) {
              @delegate[:id] = @by.send(:extract_session_id, @env)
            }
          else
            @delegate[key]
          end
        end

        def []=(k,v);         @delegate[k] = v; end
        def to_hash;          @delegate.dup; end
        def values_at(*args); @delegate.values_at(*args); end
      end

      def destroy
        clear
        options = @env[Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY] if @env
        options ||= {}
        @by.send(:destroy_session, @env, options[:id], options) if @by
        options[:id] = nil
        @loaded = false
      end

      def initialize(by, env)
        super()
        @by = by
        @env = env
        @loaded = false
      end

      def [](key)
        load_for_read!
        super(key.to_s)
      end

      def has_key?(key)
        load_for_read!
        super(key.to_s)
      end
      alias :key? :has_key?
      alias :include? :has_key?

      def []=(key, value)
        load_for_write!
        super(key.to_s, value)
      end

      def clear
        load_for_write!
        super
      end

      def to_hash
        load_for_read!
        h = {}.replace(self)
        h.delete_if { |k,v| v.nil? }
        h
      end

      def update(hash)
        load_for_write!
        super(stringify_keys(hash))
      end

      def delete(key)
        load_for_write!
        super(key.to_s)
      end

      def inspect
        if loaded?
          super
        else
          "#<#{self.class}:0x#{self.object_id.to_s(16)} not yet loaded>"
        end
      end

      def exists?
        return @exists if instance_variable_defined?(:@exists)
        @exists = @by.send(:session_exists?, @env)
      end

      def loaded?
        @loaded
      end

      def empty?
        load_for_read!
        super
      end

      private

      def load_for_read!
        load! if !loaded? && exists?
      end

      def load_for_write!
        load! unless loaded?
      end

      def load!
        id, session = @by.send(:load_session, @env)
        @env[ENV_SESSION_OPTIONS_KEY][:id] = id
        replace(stringify_keys(session))
        @loaded = true
      end

      def stringify_keys(other)
        hash = {}
        other.each do |key, value|
          hash[key.to_s] = value
        end
        hash
      end
    end
  end
end
