require 'rails/subscriber'

module Rails
  module Rack
    # Log the request started and flush all loggers after it.
    class Logger < Rails::Subscriber
      def initialize(app)
        @app = app
      end

      def call(env)
        @env = env
        before_dispatch
        result = @app.call(@env)
        after_dispatch
        result
      end

      protected

        def request
          @request ||= ActionDispatch::Request.new(@env) 
        end

        def before_dispatch
          path = request.request_uri.inspect rescue "unknown"

          info "\n\nStarted #{request.method.to_s.upcase} #{path} " <<
                      "for #{request.remote_ip} at #{Time.now.to_s(:db)}"
        end

        def after_dispatch
          Rails::Subscriber.flush_all!
        end

    end
  end
end
