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

      module DestroyableSession
        def destroy
          clear
          options = @env[Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY] if @env
          options ||= {}
          @by.send(:destroy_session, @env, options[:id], options) if @by
          options[:id] = nil
          @loaded = false
        end
      end

      ::Rack::Session::Abstract::SessionHash.send :include, DestroyableSession

      def prepare_session(env)
        session_was                  = env[ENV_SESSION_KEY]
        env[ENV_SESSION_KEY]         = Rack::Session::Abstract::SessionHash.new(self, env)
        env[ENV_SESSION_OPTIONS_KEY] = Request::Session::Options.new(self, env, @default_options)
        env[ENV_SESSION_KEY].merge! session_was if session_was
      end

      def set_cookie(env, session_id, cookie)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar[key] = cookie
      end
    end
  end

  class Request
    # SessionHash is responsible to lazily load the session from store.
    class Session
      class Options #:nodoc:
        def initialize(by, env, default_options)
          @by                = by
          @env               = env
          @session_id_loaded = false
          @delegate          = default_options
        end

        def [](key)
          load_session_id! if key == :id && session_id_not_loaded?
          @delegate[key]
        end

        def []=(k,v);        @delegate[k] = v; end
        def to_hash;         @delegate.dup; end
        def values_at(*args) @delegate.values_at(*args); end

        private
        def session_id_not_loaded?
          !(@session_id_loaded || @delegate.key?(:id))
        end

        def load_session_id!
          @delegate[:id] = @by.send(:extract_session_id, @env)
          @session_id_loaded = true
        end
      end
    end
  end
end
