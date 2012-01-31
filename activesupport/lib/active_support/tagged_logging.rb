require 'active_support/core_ext/object/blank'
require 'active_support/deprecation'
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
      @tags   = Hash.new { |h,k| h[k] = [] }
    end

    def tagged(*new_tags)
      tags     = current_tags
      new_tags = Array.wrap(new_tags).flatten.reject(&:blank?)
      tags.concat new_tags
      yield
    ensure
      new_tags.size.times { tags.pop }
    end

    def silence(temporary_level = Logger::ERROR, &block)
      @logger.silence(temporary_level, &block)
    end
    deprecate :silence

    def add(severity, message = nil, progname = nil, &block)
      message = (block_given? ? block.call : progname) if message.nil?
      @logger.add(severity, "#{tags_text}#{message}", progname)
    end

    %w( fatal error warn info debug unknown ).each do |severity|
      eval <<-EOM, nil, __FILE__, __LINE__ + 1
        def #{severity}(progname = nil, &block)
          add(Logger::#{severity.upcase}, nil, progname, &block)
        end
      EOM
    end

    def flush
      @tags.delete(Thread.current)
      @logger.flush if @logger.respond_to?(:flush)
    end

    def method_missing(method, *args)
      @logger.send(method, *args)
    end

    protected

    def tags_text
      tags = current_tags
      if tags.any?
        tags.collect { |tag| "[#{tag}]" }.join(" ") + " "
      end
    end

    def current_tags
      @tags[Thread.current]
    end
  end
end
