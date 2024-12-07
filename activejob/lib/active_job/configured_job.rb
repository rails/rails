# frozen_string_literal: true

module ActiveJob
  class ConfiguredJob # :nodoc:
    def initialize(job_class, options = {})
      @options = options
      @job_class = job_class
    end

    def perform_now(...)
      @job_class.new(...).set(@options).perform_now
    end

    def perform_later(...)
      job = @job_class.new(...)
      enqueue_result = job.enqueue(@options)

      yield job if block_given?

      enqueue_result
    end

    def perform_all_later(multi_args)
      @job_class.perform_all_later(multi_args, options: @options)
    end
  end
end
