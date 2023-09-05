# frozen_string_literal: true

class EnqueueErrorJob < ActiveJob::Base
  class EnqueueErrorAdapter
    def enqueue(*)
      raise ActiveJob::EnqueueError, "There was an error enqueuing the job"
    end

    def enqueue_at(*)
      raise ActiveJob::EnqueueError, "There was an error enqueuing the job"
    end
  end

  self.queue_adapter = EnqueueErrorAdapter.new

  def perform
    raise "This should never be called"
  end
end
