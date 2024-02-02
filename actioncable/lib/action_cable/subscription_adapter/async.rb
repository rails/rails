# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module SubscriptionAdapter
    class Async < Inline # :nodoc:
      private
        def new_subscriber_map
          AsyncSubscriberMap.new(executor)
        end

        class AsyncSubscriberMap < SubscriberMap
          def initialize(executor)
            @executor = executor
            super()
          end

          def add_subscriber(*)
            @executor.post { super }
          end

          def invoke_callback(*)
            @executor.post { super }
          end
        end
    end
  end
end
