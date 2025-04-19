# frozen_string_literal: true

module ActionMailer
  module Callbacks
    extend ActiveSupport::Concern

    included do
      include ActiveSupport::Callbacks
      define_callbacks :deliver, skip_after_callbacks_if_terminated: true
    end

    module ClassMethods
      # Defines a callback that will get called right before the
      # message is sent to the delivery method.
      def before_deliver(...)
        set_callback(:deliver, :before, ...)
      end

      # Defines a callback that will get called right after the
      # message's delivery method is finished.
      def after_deliver(...)
        set_callback(:deliver, :after, ...)
      end

      # Defines a callback that will get called around the message's deliver method.
      def around_deliver(...)
        set_callback(:deliver, :around, ...)
      end
    end
  end
end
