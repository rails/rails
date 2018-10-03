require "active_support/callbacks"

module ActionMailbox
  module Callbacks
    extend  ActiveSupport::Concern
    include ActiveSupport::Callbacks

    TERMINATOR = ->(target, chain) do
      terminate = true

      catch(:abort) do
        chain.call
        terminate = target.inbound_email.bounced?
      end

      terminate
    end

    included do
      define_callbacks :process, terminator: TERMINATOR, skip_after_callbacks_if_terminated: true
    end

    module ClassMethods
      def before_processing(*methods, &block)
        set_callback(:process, :before, *methods, &block)
      end

      def after_processing(*methods, &block)
        set_callback(:process, :after, *methods, &block)
      end

      def around_processing(*methods, &block)
        set_callback(:process, :around, *methods, &block)
      end
    end
  end
end
