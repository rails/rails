# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module SubscriptionAdapter
    class Async < Inline # :nodoc:
      private
        def new_subscriber_map
          SubscriberMap::Async.new(server)
        end
    end
  end
end
