# frozen_string_literal: true

module ActiveJob
  module Instrumentation #:nodoc:
    extend ActiveSupport::Concern

    included do
      around_enqueue do |_, block|
        scheduled_at ? instrument(:enqueue_at, &block) : instrument(:enqueue, &block)
      end

      around_perform do |_, block|
        ActiveSupport::Notifications.instrument \
          "perform_start.active_job", { adapter: queue_adapter, job: self }, &block
      end
    end

    private
      def instrument(operation, payload = {}, &block)
        enhanced_block = ->(event_payload) do
          value = block.call if block

          if defined?(@_halted_callback_hook_called) && @_halted_callback_hook_called
            event_payload[:aborted] = true
            @_halted_callback_hook_called = nil
          end

          value
        end

        ActiveSupport::Notifications.instrument \
          "#{operation}.active_job", payload.merge(adapter: queue_adapter, job: self), &enhanced_block
      end

      def halted_callback_hook(*)
        super
        @_halted_callback_hook_called = true
      end
  end
end
