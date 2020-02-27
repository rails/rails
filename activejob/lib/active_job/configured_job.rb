# frozen_string_literal: true

module ActiveJob
  class ConfiguredJob #:nodoc:
    def initialize(job_class, **options)
      @options = options
      @job_class = job_class
    end

    def perform_now(*args, **kwargs)
      @job_class.new(*args, **kwargs).perform_now
    end
    ruby2_keywords(:perform_now) if respond_to?(:ruby2_keywords, true)

    def perform_later(*args, **kwargs)
      @job_class.new(*args, **kwargs).enqueue @options
    end
    ruby2_keywords(:perform_later) if respond_to?(:ruby2_keywords, true)
  end
end
