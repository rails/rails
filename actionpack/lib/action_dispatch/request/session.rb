require 'rack/session/abstract/id'

module ActionDispatch
  class Request < Rack::Request
    # Session is responsible for lazily loading the session from store.
    class Session < Rack::Session::Abstract::SessionHash # :nodoc:
      ENV_SESSION_KEY         = Rack::Session::Abstract::ENV_SESSION_KEY # :nodoc:
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY # :nodoc:

      def self.create(store, env, default_options)
        session_was = find env
        session     = new(store, env)
        session.merge! session_was if session_was

        set(env, session)
        set_options(env, default_options.dup)
        session
      end

      def self.find(env)
        env[ENV_SESSION_KEY]
      end

      def self.set(env, session)
        env[ENV_SESSION_KEY] = session
      end

      def self.set_options(env, options)
        env[ENV_SESSION_OPTIONS_KEY] = options
      end

      def keys
        @data.keys
      end

      def values
        @data.values
      end
    end
  end
end
