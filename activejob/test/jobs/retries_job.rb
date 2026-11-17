# frozen_string_literal: true

class BeforeEnqueueError < StandardError; end

class RetriesJob < ActiveJob::Base
  attr_accessor :raise_before_enqueue

  # The job fails in before_enqueue the first time it retries itself.
  before_perform do
    self.raise_before_enqueue = true
  end

  # The job fails once to enqueue/retry itself, then succeeds.
  before_enqueue do
    raise BeforeEnqueueError if raise_before_enqueue
  ensure
    @raise_before_enqueue = false
  end

  # The job retries on BeforeEnqueueError errors.
  retry_on BeforeEnqueueError

  def perform
    retry_job if executions <= 1
  end
end
