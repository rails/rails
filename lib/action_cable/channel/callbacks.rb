module ActionCable
  module Channel

    module Callbacks
      extend ActiveSupport::Concern

      included do
        class_attribute :on_subscribe_callbacks, :on_unsubscribe_callbacks, :periodic_timers, :instance_reader => false

        self.on_subscribe_callbacks = []
        self.on_unsubscribe_callbacks = []
        self.periodic_timers = []
      end

      module ClassMethods
        def on_subscribe(*methods)
          self.on_subscribe_callbacks += methods
        end

        def on_unsubscribe(*methods)
          self.on_unsubscribe_callbacks += methods
        end

        def periodic_timer(method, every:)
          self.periodic_timers += [ [ method, every: every ] ]
        end
      end

    end

  end
end