# frozen_string_literal: true

module ActiveJob
  # = Active Job Continuable
  #
  # The Continuable module provides the ability to track the progress of your
  # jobs, and continue from where they left off if interrupted.
  #
  # Mix ActiveJob::Continuable into your job to enable continuations.
  #
  # See {ActiveJob::Continuation}[rdoc-ref:ActiveJob::Continuation] for usage.
  #
  module Continuable
    extend ActiveSupport::Concern

    included do
      class_attribute :max_resumptions, instance_writer: false
      class_attribute :resume_options, instance_writer: false, default: { wait: 5.seconds }
      class_attribute :resume_errors_after_advancing, instance_writer: false, default: true

      around_perform :continue

      def initialize(...)
        super(...)
        self.resumptions = 0
        self.continuation = Continuation.new(self, {})
      end
    end

    # The number of times the job has been resumed.
    attr_accessor :resumptions

    attr_accessor :continuation # :nodoc:

    # Start a new continuation step
    def step(step_name, start: nil, isolated: false, &block)
      unless block_given?
        step_method = method(step_name)

        raise ArgumentError, "Step method '#{step_name}' must accept 0 or 1 arguments" if step_method.arity > 1

        if step_method.parameters.any? { |type, name| type == :key || type == :keyreq }
          raise ArgumentError, "Step method '#{step_name}' must not accept keyword arguments"
        end

        block = step_method.arity == 0 ? -> (_) { step_method.call } : step_method
      end
      checkpoint! if continuation.advanced?
      continuation.step(step_name, start: start, isolated: isolated, &block)
    end

    def serialize # :nodoc:
      super.merge("continuation" => continuation.to_h, "resumptions" => resumptions)
    end

    def deserialize(job_data) # :nodoc:
      super
      self.continuation = Continuation.new(self, job_data.fetch("continuation", {}))
      self.resumptions = job_data.fetch("resumptions", 0)
    end

    def checkpoint! # :nodoc:
      interrupt!(reason: :stopping) if queue_adapter.stopping?
    end

    def interrupt!(reason:) # :nodoc:
      instrument :interrupt, reason: reason, **continuation.instrumentation
      raise Continuation::Interrupt, "Interrupted #{continuation.description} (#{reason})"
    end

    private
      def continue(&block)
        if continuation.started?
          self.resumptions += 1
          instrument :resume, **continuation.instrumentation
        end

        block.call
      rescue Continuation::Interrupt => e
        resume_job(e)
      rescue Continuation::Error
        raise
      rescue StandardError => e
        if resume_errors_after_advancing? && continuation.advanced?
          resume_job(exception: e)
        else
          raise
        end
      end

      def resume_job(exception) # :nodoc:
        executions_for(exception)
        if max_resumptions.nil? || resumptions < max_resumptions
          retry_job(**self.resume_options)
        else
          raise Continuation::ResumeLimitError, "Job was resumed a maximum of #{max_resumptions} times"
        end
      end
  end

  ActiveSupport.run_load_hooks(:active_job_continuable, Continuable)
end
