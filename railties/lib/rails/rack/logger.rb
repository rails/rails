require 'active_support/core_ext/time/conversions'

module Rails
  module Rack
    # Log the request started and flush all loggers after it.
    class Logger < ActiveSupport::LogSubscriber
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
        path = request.filtered_path

        info "\n\nStarted #{request.request_method} \"#{path}\" " \
             "for #{request.ip} at #{Time.now.to_default_s}"
      end

      def after_dispatch(env)
        ActiveSupport::LogSubscriber.flush_all!
      end
    end
  end
end
