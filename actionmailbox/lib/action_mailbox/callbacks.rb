# frozen_string_literal: true

require "active_support/callbacks"

module ActionMailbox
  # = Action Mailbox \Callbacks
  #
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
      def before_processing(...)
        set_callback(:process, :before, ...)
      end

      def after_processing(...)
        set_callback(:process, :after, ...)
      end

      def around_processing(...)
        set_callback(:process, :around, ...)
      end
    end
  end
end
