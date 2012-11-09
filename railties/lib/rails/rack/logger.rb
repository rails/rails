require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/object/blank'

module Rails
  module Rack
    # Sets log tags, logs the request, calls the app, and flushes the logs.
    class Logger < ActiveSupport::LogSubscriber
      def initialize(app, taggers = nil)
        @app, @taggers = app, taggers || []
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if Rails.logger.respond_to?(:tagged)
          Rails.logger.tagged(compute_tags(request)) { call_app(request, env) }
        else
          call_app(request, env)
        end
      end

    protected

      def call_app(request, env)
        # Put some space between requests in development logs.
        if Rails.env.development?
          Rails.logger.debug ''
          Rails.logger.debug ''
        end

        Rails.logger.info started_request_message(request)
        @app.call(env)
      ensure
        ActiveSupport::LogSubscriber.flush_all!
      end

      # Started GET "/session/new" for 127.0.0.1 at 2012-09-26 14:51:42 -0700
      def started_request_message(request)
        'Started %s "%s" for %s at %s' % [
          request.request_method,
          request.filtered_path,
          request.ip,
          Time.now.to_default_s ]
      end

      def compute_tags(request)
        @taggers.collect do |tag|
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
