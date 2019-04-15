# frozen_string_literal: true

module ActiveJob
  class ConfiguredJob #:nodoc:
    def initialize(job_class, options = {})
      @job_class = job_class
      @options = options
    end

    def perform_now(*args)
      @job_class.new(*args).perform_now
    end

    def perform_later(*args)
      @job_class.new(*args).enqueue @options
    end
  end
end
