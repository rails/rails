# frozen_string_literal: true

module ActiveJob
  # = Active Job Continuable
  #
  # Mix ActiveJob::Continuable into your job to enable continuations.
  #
  # See +ActiveJob::Continuation+ for usage. # The Continuable module provides the ability to track the progress of your jobs,
  # and continue from where they left off if interrupted.
  #
  module Continuable
    extend ActiveSupport::Concern

    CONTINUATION_KEY = "continuation"

    included do
      retry_on Continuation::Interrupt, attempts: :unlimited
      retry_on Continuation::AfterAdvancingError, attempts: :unlimited

      around_perform :continue
    end

    def step(step_name, start: nil, &block)
      unless block_given?
        step_method = method(step_name)

        raise ArgumentError, "Step method '#{step_name}' must accept 0 or 1 arguments" if step_method.arity > 1

        if step_method.parameters.any? { |type, name| type == :key || type == :keyreq }
          raise ArgumentError, "Step method '#{step_name}' must not accept keyword arguments"
        end

        block = step_method.arity == 0 ? -> (_) { step_method.call } : step_method
      end
      continuation.step(step_name, start: start, &block)
    end

    def serialize
      super.merge(CONTINUATION_KEY => continuation.to_h)
    end

    def deserialize(job_data)
      super
      @continuation = Continuation.new(self, job_data.fetch(CONTINUATION_KEY, {}))
    end

    private
      def continuation
        @continuation ||= Continuation.new(self, {})
      end

      def continue(&block)
        continuation.continue(&block)
      end
  end
end
