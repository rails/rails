require 'logger'

module ActiveSupport
  # Wraps any standard Logger class to provide tagging capabilities. Examples:
  #
  #   Logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
  #   Logger.tagged("BCX") { Logger.info "Stuff" }                            # Logs "[BCX] Stuff"
  #   Logger.tagged("BCX", "Jason") { Logger.info "Stuff" }                   # Logs "[BCX] [Jason] Stuff"
  #   Logger.tagged("BCX") { Logger.tagged("Jason") { Logger.info "Stuff" } } # Logs "[BCX] [Jason] Stuff"
  #
  # This is used by the default Rails.logger as configured by Railties to make it easy to stamp log lines
  # with subdomains, request ids, and anything else to aid debugging of multi-user production applications.
  class TaggedLogging
    def initialize(logger)
      @logger = logger
      @tags   = []
    end

    def tagged(*tags)
      new_tags = Array.wrap(tags).flatten
      @tags += new_tags
      yield
    ensure
      new_tags.size.times { @tags.pop }
    end


    def add(severity, message = nil, progname = nil, &block)
      @logger.add(severity, "#{tags}#{message}", progname, &block)
    end

    %w( fatal error warn info debug unkown ).each do |severity|
      eval <<-EOM, nil, __FILE__, __LINE__ + 1
        def #{severity}(progname = nil, &block)
          add(Logger::#{severity.upcase}, progname, &block)
        end
      EOM
    end


    def method_missing(method, *args)
      @logger.send(method, *args)
    end
    

    private
      def tags
        if @tags.any?
          @tags.collect { |tag| "[#{tag}]" }.join(" ") + " "
        end
      end
  end
end
