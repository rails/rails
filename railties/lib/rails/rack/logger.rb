# frozen_string_literal: true

require "active_support/core_ext/time/conversions"
require "active_support/log_subscriber"
require "rack/body_proxy"

module Rails
  module Rack
    # Sets log tags, logs the request, calls the app, and flushes the logs.
    #
    # Log tags (+taggers+) can be an Array containing: methods that the +request+
    # object responds to, objects that respond to +to_s+ or Proc objects that accept
    # an instance of the +request+ object.
    class Logger < ActiveSupport::LogSubscriber
      def initialize(app, taggers = nil)
        @app          = app
        @taggers      = taggers || []
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        env["rails.rack_logger_tag_count"] = if logger.respond_to?(:push_tags)
          logger.push_tags(*compute_tags(request)).size
        else
          0
        end

        call_app(request, env)
      end

      private
        def call_app(request, env) # :doc:
          logger_tag_pop_count = env["rails.rack_logger_tag_count"]

          instrumenter = ActiveSupport::Notifications.instrumenter
          handle = instrumenter.build_handle("request.action_dispatch", { request: request })
          handle.start

          logger.info { started_request_message(request) }
          status, headers, body = response = @app.call(env)
          body = ::Rack::BodyProxy.new(body) { finish_request_instrumentation(handle, logger_tag_pop_count) }

          if response.frozen?
            [status, headers, body]
          else
            response[2] = body
            response
          end
        rescue Exception
          finish_request_instrumentation(handle, logger_tag_pop_count)
          raise
        end

        # Started GET "/session/new" for 127.0.0.1 at 2012-09-26 14:51:42 -0700
        def started_request_message(request) # :doc:
          sprintf('Started %s "%s" for %s at %s',
            request.raw_request_method,
            request.filtered_path,
            request.remote_ip,
            Time.now)
        end

        def compute_tags(request) # :doc:
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

        def logger
          Rails.logger
        end

        def finish_request_instrumentation(handle, logger_tag_pop_count)
          handle.finish
          logger.pop_tags(logger_tag_pop_count) if logger.respond_to?(:pop_tags) && logger_tag_pop_count > 0
          ActiveSupport::LogSubscriber.flush_all!
        end
    end
  end
end
