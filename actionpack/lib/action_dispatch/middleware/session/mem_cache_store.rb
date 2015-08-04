require 'action_dispatch/middleware/session/abstract_store'
begin
  require 'rack/session/dalli'
rescue LoadError => e
  $stderr.puts "You don't have dalli installed in your application. Please add it to your Gemfile and run bundle install"
  raise e
end

module ActionDispatch
  module Session
    # A session store that uses MemCache to implement storage.
    #
    # ==== Options
    # * <tt>expire_after</tt>  - The length of time a session will be stored before automatically expiring.
    class MemCacheStore < Rack::Session::Dalli
      include Compatibility
      include StaleSessionCheck
      include SessionObject

      def initialize(app, options = {})
        options[:expire_after] ||= options[:expires]
        super
      end
    end
  end
end
