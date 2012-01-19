require 'active_support/core_ext/object/blank'
require 'logger'
require 'active_support/logger'

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
  module TaggedLogging
    class Formatter < ActiveSupport::Logger::SimpleFormatter # :nodoc:
      # This method is invoked when a log event occurs
      def call(severity, timestamp, progname, msg)
        super(severity, timestamp, progname, "#{tags_text}#{msg}")
      end

      def clear!
        current_tags.clear
      end

      def current_tags
        Thread.current[:activesupport_tagged_logging_tags] ||= []
      end

      private
      def tags_text
        tags = current_tags
        if tags.any?
          tags.collect { |tag| "[#{tag}] " }.join
        end
      end
    end

    def self.new(logger)
      logger.formatter = Formatter.new
      logger.extend(self)
    end

    def tagged(*new_tags)
      tags     = formatter.current_tags
      new_tags = new_tags.flatten.reject(&:blank?)
      tags.concat new_tags
      yield
    ensure
      tags.pop(new_tags.size)
    end

    def flush
      formatter.clear!
      super if defined?(super)
    end
  end
end
