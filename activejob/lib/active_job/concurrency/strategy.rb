# frozen_string_literal: true

module ActiveJob
  module Concurrency
    class Strategy
      ENQUEUE_STRATEGY = :enqueue
      PERFORM_STRATEGY = :enqueue
      ENQUEUE_AND_PERFORM_STRATEGY = :enqueue_and_perform
      END_TO_END_STRATEGY = :end_to_end

      def initialize(job)
        @job = job
      end

      def any?
        @job.concurrency_strategy.present?
      end

      def enqueue_limit?
        case @job.concurrency_strategy
        when ENQUEUE_STRATEGY, ENQUEUE_AND_PERFORM_STRATEGY, END_TO_END_STRATEGY
          true
        else
          false
        end
      end

      def perform_limit?
        case @job.concurrency_strategy
        when PERFORM_STRATEGY, ENQUEUE_AND_PERFORM_STRATEGY
          true
        else
          false
        end
      end

      def enqueue_limit
        @job.concurrency_enqueue_limit
      end

      def perform_limit
        @job.concurrency_perform_limit
      end
    end
  end
end
