# frozen_string_literal: true

require_relative "async"

module ActionCable
  module SubscriptionAdapter
    # == Test adapter for Action Cable
    #
    # The test adapter should be used only in testing. Along with
    # ActionCable::TestHelper it makes a great tool to test your Rails application.
    #
    # To use the test adapter set +adapter+ value to +test+ in your +config/cable.yml+ file.
    #
    # NOTE: Test adapter extends the <tt>ActionCable::SubscriptionsAdapter::Async</tt> adapter,
    # so it could be used in system tests too.
    class Test < Async
      def broadcast(channel, payload)
        broadcasts(channel) << payload
        super
      end

      def broadcasts(channel)
        channels_data[channel] ||= []
      end

      def clear_messages(channel)
        channels_data[channel] = []
      end

      def clear
        @channels_data = nil
      end

      private
        def channels_data
          @channels_data ||= {}
        end
    end
  end
end
