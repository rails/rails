require 'rack/utils'
require 'rack/request'
require 'rack/session/abstract/id'
require 'action_dispatch/middleware/cookies'
require 'active_support/core_ext/object/blank'

module ActionDispatch
  module Session
    class SessionRestoreError < StandardError #:nodoc:
    end

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

    module Compatibility
      def initialize(app, options = {})
        options[:key] ||= '_session_id'
        super
      end

      def generate_sid
        sid = SecureRandom.hex(16)
        sid.encode!('UTF-8') if sid.respond_to?(:encode!)
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
          rescue LoadError, NameError => const_error
            raise ActionDispatch::Session::SessionRestoreError,
              "Session contains objects whose class definition isn't available.\n" +
              "Remember to require the classes for all objects kept in the session.\n" +
              "(Original exception: #{const_error.message} [#{const_error.class}])\n"
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

      private

      def set_cookie(env, session_id, cookie)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar[key] = cookie
      end
    end
  end
end
