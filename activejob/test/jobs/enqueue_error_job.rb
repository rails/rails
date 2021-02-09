# frozen_string_literal: true

class EnqueueErrorJob < ActiveJob::Base
  class EnqueueErrorAdapter
    class << self
      def enqueue(*)
        raise ActiveJob::EnqueueError, "There was an error enqueuing the job"
      end

      def enqueue_at(*)
        raise ActiveJob::EnqueueError, "There was an error enqueuing the job"
      end

      def concurrency_reached?(strategy, job)
        false
      end

      def clear_concurrency(strategy, job)
      end
    end
  end

  self.queue_adapter = EnqueueErrorAdapter

  def perform
    raise "This should never be called"
  end
end
