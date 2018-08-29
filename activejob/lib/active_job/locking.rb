# frozen_string_literal: true

module ActiveJob
  # Provides behavior for controlling how many of a job can be enqueued.
  module Locking
    extend ActiveSupport::Concern

    included do
      class_attribute :_lock_key, instance_accessor: false
      class_attribute :_lock_timeout, instance_accessor: false
    end

    module ClassMethods
      def lock_key
        self._lock_key
      end

      def lock_timeout
        self._lock_timeout
      end

      def locked_by(key:, timeout:)
        self._lock_key = key
        self._lock_timeout = timeout
      end
    end

    def lock_timeout
      @lock_timeout ||= self.class.lock_timeout.to_i
    end

    def lock_key
      return nil unless lock_timeout > 0 && !self.class.lock_key.nil?
      @lock_key ||= self.class.lock_key.call(self)
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
