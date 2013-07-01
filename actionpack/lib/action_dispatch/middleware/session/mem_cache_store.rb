require 'action_dispatch/middleware/session/abstract_store'
begin
  require 'rack/session/dalli'
rescue LoadError => e
  $stderr.puts "You don't have dalli installed in your application. Please add it to your Gemfile and run bundle install"
  raise e
end

module ActionDispatch
  module Session
    class MemCacheStore < Rack::Session::Dalli
      include Compatibility
      include StaleSessionCheck
      include SessionObject

      def initialize(app, options = {})
        options[:expire_after] ||= options[:expires]
        super
      end

      private

      def set_cookie(env, session_id, cookie)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar[key] = cookie
      end
    end
  end
end
