# frozen_string_literal: true

module ActiveJob
  module Concurrency
    class Limit
      def initialize(limit)
        @limit = lmit
      end

      def locking?
        @limit.is_a?(Numeric)
      end

      def enqueue_limit?
        @limit.is_a?(Hash) && @limit.key?(:enqueue)
      end

      def perform_limit?
        @limit.is_a?(Hash) && @limit.key?(:perform)
      end

      def enqueue_limit
        return @limit if locking?
        @limit[:enqueue] if enqueue_limit?
      end

      def perform_limit
        @limit[:perform] if perform_limit?
      end
    end
  end
end
