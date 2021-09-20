# frozen_string_literal: true

require "active_support/core_ext/time/conversions"
require "active_support/core_ext/object/blank"
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
      def initialize(app, taggers = nil, tag_computer = nil)
        @app          = app
        @taggers      = taggers || []
        @tag_computer = tag_computer || lambda { |request, _| compute_tags(request) }
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if logger.respond_to?(:tagged)
          logger.tagged(@tag_computer.call(request, @taggers)) { call_app(request, env) }
        else
          call_app(request, env)
        end
      end

      private
        def call_app(request, env) # :doc:
          instrumenter = ActiveSupport::Notifications.instrumenter
          instrumenter.start "request.action_dispatch", request: request
          logger.info { started_request_message(request) }
          status, headers, body = @app.call(env)
          body = ::Rack::BodyProxy.new(body) { finish(request) }
          [status, headers, body]
        rescue Exception
          finish(request)
          raise
        ensure
          ActiveSupport::LogSubscriber.flush_all!
        end

        # Started GET "/session/new" for 127.0.0.1 at 2012-09-26 14:51:42 -0700
        def started_request_message(request) # :doc:
          'Started %s "%s" for %s at %s' % [
            request.raw_request_method,
            request.filtered_path,
            request.remote_ip,
            Time.now.to_default_s ]
        end

        def compute_tags(request) # :doc:
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            The compute_tags method in Rails::Rack::Logger is deprecated and will
            be removed in Rails 7.2. Tag computation can now be configured by
            instantiating Rails::Rack::Logger with a callable that takes the request
            and taggers as arguments.

            To restore the current functionality, you should pass
            ActiveSupport::TaggedLogging::TagComputer as the third argument
            when adding Rails::Rack::Logger to the middleware stack.

            For example:

            app.middleware.use Rails::Rack::Logger, [:request_id], ActiveSupport::TaggedLogging::TagComputer
          MSG

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

        def finish(request)
          instrumenter = ActiveSupport::Notifications.instrumenter
          instrumenter.finish "request.action_dispatch", request: request
        end

        def logger
          Rails.logger
        end
    end
  end
end
