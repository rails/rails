require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/object/blank'

module Rails
  module Rack
    # Log the request started and flush all loggers after it.
    class Logger < ActiveSupport::LogSubscriber
      def initialize(app, tags=nil)
        @app, @tags = app, tags.presence
      end

      def call(env)
        if @tags
          Rails.logger.tagged(compute_tags(env)) { call_app(env) }
        else
          call_app(env)
        end
      end

    protected

      def call_app(env)
        request = ActionDispatch::Request.new(env)
        path = request.filtered_path
        Rails.logger.info "\n\nStarted #{request.request_method} \"#{path}\" for #{request.ip} at #{Time.now.to_default_s}"
        @app.call(env)
      ensure
        ActiveSupport::LogSubscriber.flush_all!
      end

      def compute_tags(env)
        request = ActionDispatch::Request.new(env)

        @tags.collect do |tag|
          case tag
          when Proc
            tag.call(request)
          when Symbol
            request.send(tag)
          else
            tag
          end
        end
      end
    end
  end
end
