# frozen_string_literal: true

module ActiveJob
  class ConfiguredJob #:nodoc:
    def initialize(job_class, options = {})
      @options = options
      @job_class = job_class
    end

    def perform_now(...)
      @job_class.new(...).perform_now
    end

    def perform_later(...)
      @job_class.new(...).enqueue @options
    end
  end
end
