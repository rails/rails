# frozen_string_literal: true

class EnqueueErrorJob < ActiveJob::Base
  class EnqueueErrorAdapter
    class << self
      attr_accessor :should_raise_sequence
    end
    self.should_raise_sequence = []

    def enqueue(*)
      raise ActiveJob::EnqueueError, "There was an error enqueuing the job" if should_raise?
    end

    def enqueue_at(*)
      raise ActiveJob::EnqueueError, "There was an error enqueuing the job" if should_raise?
    end

    private
      def should_raise?
        self.class.should_raise_sequence.empty? || self.class.should_raise_sequence.shift
      end
  end

  self.queue_adapter = EnqueueErrorAdapter.new

  def perform
    raise "This should never be called"
  end
end
