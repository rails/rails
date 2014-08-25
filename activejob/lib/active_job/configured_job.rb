module ActiveJob
  class ConfiguredJob #:nodoc:
    def initialize(job_class, options={})
      @options = options
      @options[:in] = @options.delete(:wait) if @options[:wait]
      @options[:at] = @options.delete(:wait_until) if @options[:wait_until]
      @job_class = job_class
    end

    def perform_now(*args)
      @job_class.new(*args).perform_now
    end

    def perform_later(*args)
      @job_class.new(*args).enqueue @options
    end
  end
end
