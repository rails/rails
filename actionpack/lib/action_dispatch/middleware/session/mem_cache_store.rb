require 'action_dispatch/middleware/session/abstract_store'
require 'rack/session/memcache'

module ActionDispatch
  module Session
    class MemCacheStore < Rack::Session::Memcache
      include Compatibility
      include StaleSessionCheck

      def initialize(app, options = {})
        require 'memcache'
        options[:expire_after] ||= options[:expires]
        super
      end

      private

      def prepare_session(env)
        Request::Session.create(self, env, @default_options)
      end

      def loaded_session?(session)
        !session.is_a?(Request::Session) || session.loaded?
      end
    end
  end
end
