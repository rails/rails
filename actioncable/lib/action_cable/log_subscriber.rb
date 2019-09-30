# frozen_string_literal: true

require "active_support/log_subscriber"

module ActionCable
  class LogSubscriber < ActiveSupport::LogSubscriber
    def start_request(event)
      tagged_for event do
        info { "Started #{request_details_for(event)}" }
      end
    end

    def upgrade_request(event)
      tagged_for event do
        if event.payload[:succeeded]
          info { "Successfully upgraded to WebSocket #{upgrade_details_for(event.payload[:request])}" }
        else
          error { "Failed to upgrade to WebSocket #{upgrade_details_for(event.payload[:request])}" }
          info { "Finished #{request_details_for(event)}" }
        end
      end
    end

    def websocket_error(event)
      tagged_for(event) { error event.payload[:message] }
    end

    def finish_request(event)
      tagged_for event do
        info { "Finished #{request_details_for(event)}" }
      end
    end

    def perform_action(event)
      tagged_for event do
        if event.payload[:succeeded]
          info action_signature_in(event)
        else
          error "Unable to process #{action_signature_in(event)}"
        end
      end
    end

    def transmit(event)
      tagged_for event do
        debug do
          "#{event.payload[:channel_class]} transmitting #{event.payload[:data].inspect.truncate(300)}".tap do |message|
            message << " (via #{event.payload[:via]})" if event.payload[:via]
          end
        end
      end
    end

    def transmit_subscription_confirmation(event)
      tagged_for event do
        debug { "#{event.payload[:channel_class]} is transmitting the subscription confirmation" }
      end
    end

    def transmit_subscription_rejection(event)
      tagged_for event do
        debug { "#{event.payload[:channel_class]} is transmitting the subscription rejection" }
      end
    end

    def logger
      ActionCable.server.logger
    end

    private
      def tagged_for(event, &block)
        if logger.respond_to?(:tagged) && connection = event.payload[:connection]
          logger.tagged tags_for(connection), &block
        else
          yield
        end
      end

      def tags_for(connection)
        tags.map { |tag| tag.respond_to?(:call) ? tag.call(connection.request) : tag.to_s.camelize }
      end

      def tags
        ActionCable.server.config.log_tags
      end


      def request_details_in(event)
        request   = event.payload[:request]
        websocket = event.payload[:websocket]

        sprintf '%s "%s"%s for %s at %s',
          request.request_method,
          request.filtered_path,
          websocket.possible? ? " [WebSocket]" : "[non-WebSocket]",
          request.ip,
          event.time
      end

      def upgrade_details_for(request)
        sprintf "(REQUEST_METHOD: %s, HTTP_CONNECTION: %s, HTTP_UPGRADE: %s)",
          request.env["REQUEST_METHOD"], request.env["HTTP_CONNECTION"], request.env["HTTP_UPGRADE"]
      end

      def action_signature_in(event)
        "#{event.payload[:channel_class]}##{event.payload[:action]}".tap do |message|
          if (arguments = event.payload[:data].except("action")).any?
            message << "(#{arguments.inspect})"
          end
        end
      end
  end
end

ActionCable::LogSubscriber.attach_to :action_cable
