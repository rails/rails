module ActionCable
  module SubscriptionAdapter
    # == Test adapter for Action Cable
    #
    # The test adapter should be used only in testing. Along with
    # <tt>ActionCable::TestHelper</tt> it makes a great tool to test your Rails application.
    #
    # To use the test adapter set adapter value to +test+ in your +cable.yml+.
    class Test < Base
      def broadcast(channel, payload)
        broadcasts(channel) << payload
      end

      def broadcasts(channel)
        channels_data[channel] ||= []
      end

      def clear_messages(channel)
        channels_data[channel] = []
      end

      def reset!
        @channels_data = nil
      end

      private
        def channels_data
          @channels_data ||= {}
        end
    end
  end
end
