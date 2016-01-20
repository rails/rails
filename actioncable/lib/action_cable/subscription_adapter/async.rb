require 'action_cable/subscription_adapter/inline'

module ActionCable
  module SubscriptionAdapter
    class Async < Inline # :nodoc:
      private
        def subscriber_map
          @subscriber_map ||= AsyncSubscriberMap.new
        end

        class AsyncSubscriberMap < SubscriberMap
          def add_subscriber(*)
            Concurrent.global_io_executor.post { super }
          end

          def invoke_callback(*)
            Concurrent.global_io_executor.post { super }
          end
        end
    end
  end
end
