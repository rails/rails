# frozen_string_literal: true

module ActiveJob
  module Instrumentation #:nodoc:
    extend ActiveSupport::Concern

    included do
      around_enqueue do |job, block|
        if job.scheduled_at
          ActiveSupport::Notifications.instrument("enqueue_at.active_job",
            adapter: job.class.queue_adapter, job: job, &block)
        else
          ActiveSupport::Notifications.instrument("enqueue.active_job",
            adapter: job.class.queue_adapter, job: job, &block)
        end
      end

      around_perform do |job, block|
        payload = { adapter: job.class.queue_adapter, job: job }
        ActiveSupport::Notifications.instrument("perform_start.active_job", payload.dup)
        ActiveSupport::Notifications.instrument("perform.active_job", payload) do
          block.call
        end
      end
    end
  end
end
