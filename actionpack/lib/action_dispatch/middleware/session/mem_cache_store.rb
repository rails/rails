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
    end
  end
end
