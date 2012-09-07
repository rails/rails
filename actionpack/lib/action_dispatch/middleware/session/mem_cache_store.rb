require 'action_dispatch/middleware/session/abstract_store'
require 'rack/session/dalli'

module ActionDispatch
  module Session
    class MemCacheStore < Rack::Session::Dalli
      include Compatibility
      include StaleSessionCheck
      include SessionObject

      def initialize(app, options = {})
        require 'dalli'
        options[:expire_after] ||= options[:expires]
        super
      end
    end
  end
end
