# frozen_string_literal: true

module ActiveJob
  module Instrumentation #:nodoc:
    extend ActiveSupport::Concern

    included do
      around_enqueue do |_, block|
        scheduled_at ? instrument(:enqueue_at, &block) : instrument(:enqueue, &block)
      end

      around_perform do |_, block|
        instrument :perform_start
        instrument :perform, &block
      end
    end

    private
      def instrument(operation, payload = {}, &block)
        enhanced_block = ->(event_payload) do
          aborted = !block.call if block
          event_payload[:aborted] = true if aborted
        end

        ActiveSupport::Notifications.instrument \
          "#{operation}.active_job", payload.merge(adapter: queue_adapter, job: self), &enhanced_block
      end
  end
end
