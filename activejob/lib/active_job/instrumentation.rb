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
        ActiveSupport::Notifications.instrument \
          "#{operation}.active_job", payload.merge(adapter: queue_adapter, job: self), &block
      end
  end
end
