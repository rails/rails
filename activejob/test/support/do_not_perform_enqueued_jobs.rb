# frozen_string_literal: true

module DoNotPerformEnqueuedJobs
  extend ActiveSupport::Concern

  included do
    setup do
      # /rails/activejob/test/adapters/test.rb sets these configs to true, but
      # in this specific case we want to test enqueueing behavior.
      @perform_enqueued_jobs = queue_adapter.perform_enqueued_jobs
      @perform_enqueued_at_jobs = queue_adapter.perform_enqueued_at_jobs
      queue_adapter.perform_enqueued_jobs = queue_adapter.perform_enqueued_at_jobs = false
    end

    teardown do
      queue_adapter.perform_enqueued_jobs = @perform_enqueued_jobs
      queue_adapter.perform_enqueued_at_jobs = @perform_enqueued_at_jobs
    end
  end
end
