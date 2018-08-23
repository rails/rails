# frozen_string_literal: true

module ActiveJob
  # Provides behavior for controlling how many of a job can be enqueued.
  module Locking
    def initialize(*arguments)
      super

      @lock_timeout = self.class.lock_timeout.to_i
      if @lock_timeout > 0 && !self.class.lock_key.nil?
        @lock_key = self.class.lock_key.call(self)
      end
    end

    # We determine if a job is locking based on whether or not a timeout
    # and key are present. Both are required for a lock.
    def locking?
      !lock_key.nil? && lock_timeout > 0
    end

    def clear_lock
      self.class.queue_adapter.clear_lock(self)
    end
  end
end
