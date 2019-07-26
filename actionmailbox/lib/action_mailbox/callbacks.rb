# frozen_string_literal: true

require "active_support/callbacks"

module ActionMailbox
  # Defines the callbacks related to processing.
  module Callbacks
    extend  ActiveSupport::Concern
    include ActiveSupport::Callbacks

    TERMINATOR = ->(mailbox, chain) do
      chain.call
      mailbox.finished_processing?
    end

    included do
      define_callbacks :process, terminator: TERMINATOR, skip_after_callbacks_if_terminated: true
    end

    class_methods do
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
