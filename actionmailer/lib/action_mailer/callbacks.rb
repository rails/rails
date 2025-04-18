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
      def before_deliver(*filters, &blk)
        set_callback(:deliver, :before, *filters, &blk)
      end

      # Defines a callback that will get called right after the
      # message's delivery method is finished.
      def after_deliver(*filters, &blk)
        set_callback(:deliver, :after, *filters, &blk)
      end

      # Defines a callback that will get called around the message's deliver method.
      def around_deliver(*filters, &blk)
        set_callback(:deliver, :around, *filters, &blk)
      end
    end
  end
end
