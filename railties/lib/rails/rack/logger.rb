require 'rails/subscriber'

module Rails
  module Rack
    # Log the request started and flush all loggers after it.
    class Logger < Rails::Subscriber
      def initialize(app)
        @app = app
      end

      def call(env)
        before_dispatch(env)
        @app.call(env)
      ensure
        after_dispatch(env)
      end

      protected

        def before_dispatch(env)
          request = ActionDispatch::Request.new(env)
          path = request.request_uri.inspect rescue "unknown"

          info "\n\nStarted #{request.method.to_s.upcase} #{path} " <<
                      "for #{request.remote_ip} at #{Time.now.to_s(:db)}"
        end

        def after_dispatch(env)
          Rails::Subscriber.flush_all!
        end

    end
  end
end
