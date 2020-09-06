# frozen_string_literal: true

require 'action_cable/subscription_adapter/inline'

module ActionCable
  module SubscriptionAdapter
    class Async < Inline # :nodoc:
      private
        def new_subscriber_map
          AsyncSubscriberMap.new(server.event_loop)
        end

        class AsyncSubscriberMap < SubscriberMap
          def initialize(event_loop)
            @event_loop = event_loop
            super()
          end

          def add_subscriber(*)
            @event_loop.post { super }
          end

          def invoke_callback(*)
            @event_loop.post { super }
          end
        end
    end
  end
end
