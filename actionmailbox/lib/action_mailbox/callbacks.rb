# :markup: markdown
# frozen_string_literal: true

require "active_support/callbacks"

module ActionMailbox
  # Action Mailbox \Callbacks
  # =========================
  #
  # Defines the callbacks related to processing.
  module Callbacks
    extend  ActiveSupport::Concern
    include ActiveSupport::Callbacks

    # Implements call_direct so that before callbacks don't have to allocate
    # a thunk per invocation (see ActiveSupport::Callbacks::Filters::Before).
    class Terminator # :nodoc:
      def call(mailbox, chain)
        chain.call
        mailbox.finished_processing?
      end

      def call_direct(mailbox, user_callback, value)
        user_callback.call(mailbox, value)
        mailbox.finished_processing?
      end
    end
    TERMINATOR = Terminator.new.freeze

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
