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
    end

    def tagged(*tags)
      new_tags = push_tags(*tags)
      yield self
    ensure
      pop_tags(new_tags.size)
    end

    def push_tags(*tags)
      tags.flatten.reject(&:blank?).tap do |new_tags|
        current_tags.concat new_tags
      end
    end

    def pop_tags(size = 1)
      current_tags.pop size
    end

    def clear_tags!
      current_tags.clear
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
      clear_tags!
      @logger.flush if @logger.respond_to?(:flush)
    end

    def method_missing(method, *args)
      @logger.send(method, *args)
    end

    private
      def tags_text
        tags = current_tags
        if tags.any?
          tags.collect { |tag| "[#{tag}] " }.join
        end
      end

      def current_tags
        Thread.current[:activesupport_tagged_logging_tags] ||= []
      end
  end
end
