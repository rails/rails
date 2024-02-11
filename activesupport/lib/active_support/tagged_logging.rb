# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "logger"
require "active_support/logger"

module ActiveSupport
  # = Active Support Tagged Logging
  #
  # Wraps any standard Logger object to provide tagging capabilities.
  #
  # May be called with a block:
  #
  #   logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
  #   logger.tagged('BCX') { logger.info 'Stuff' }                                  # Logs "[BCX] Stuff"
  #   logger.tagged('BCX', "Jason") { |tagged_logger| tagged_logger.info 'Stuff' }  # Logs "[BCX] [Jason] Stuff"
  #   logger.tagged('BCX') { logger.tagged('Jason') { logger.info 'Stuff' } }       # Logs "[BCX] [Jason] Stuff"
  #
  # If called without a block, a new logger will be returned with applied tags:
  #
  #   logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
  #   logger.tagged("BCX").info "Stuff"                 # Logs "[BCX] Stuff"
  #   logger.tagged("BCX", "Jason").info "Stuff"        # Logs "[BCX] [Jason] Stuff"
  #   logger.tagged("BCX").tagged("Jason").info "Stuff" # Logs "[BCX] [Jason] Stuff"
  #
  # This is used by the default Rails.logger as configured by Railties to make
  # it easy to stamp log lines with subdomains, request ids, and anything else
  # to aid debugging of multi-user production applications.
  module TaggedLogging
    module Formatter # :nodoc:
      # This method is invoked when a log event occurs.
      def call(severity, timestamp, progname, msg)
        super(severity, timestamp, progname, tag_stack.format_message(msg))
      end

      def tagged(*tags)
        pushed_count = tag_stack.push_tags(tags).size
        yield self
      ensure
        pop_tags(pushed_count)
      end

      def push_tags(*tags)
        tag_stack.push_tags(tags)
      end

      def pop_tags(count = 1)
        tag_stack.pop_tags(count)
      end

      def clear_tags!
        tag_stack.clear
      end

      def tag_stack
        # We use our object ID here to avoid conflicting with other instances
        @thread_key ||= "activesupport_tagged_logging_tags:#{object_id}"
        IsolatedExecutionState[@thread_key] ||= TagStack.new
      end

      def current_tags
        tag_stack.tags
      end

      def tags_text
        tag_stack.format_message("")
      end
    end

    class TagStack # :nodoc:
      attr_reader :tags

      def initialize
        @tags = []
        @tags_string = nil
      end

      def push_tags(tags)
        @tags_string = nil
        tags.flatten!
        tags.reject!(&:blank?)
        @tags.concat(tags)
        tags
      end

      def pop_tags(count)
        @tags_string = nil
        @tags.pop(count)
      end

      def clear
        @tags_string = nil
        @tags.clear
      end

      def format_message(message)
        if @tags.empty?
          message
        elsif @tags.size == 1
          "[#{@tags[0]}] #{message}"
        else
          @tags_string ||= "[#{@tags.join("] [")}] "
          "#{@tags_string}#{message}"
        end
      end
    end

    module LocalTagStorage # :nodoc:
      attr_accessor :tag_stack

      def self.extended(base)
        base.tag_stack = TagStack.new
      end
    end

    def self.new(logger)
      logger = logger.clone

      if logger.formatter
        logger.formatter = logger.formatter.clone

        # Workaround for https://bugs.ruby-lang.org/issues/20250
        # Can be removed when Ruby 3.4 is the least supported version.
        logger.formatter.object_id if logger.formatter.is_a?(Proc)
      else
        # Ensure we set a default formatter so we aren't extending nil!
        logger.formatter = ActiveSupport::Logger::SimpleFormatter.new
      end

      logger.formatter.extend Formatter
      logger.extend(self)
    end

    delegate :push_tags, :pop_tags, :clear_tags!, to: :formatter

    def tagged(*tags)
      if block_given?
        formatter.tagged(*tags) { yield self }
      else
        logger = ActiveSupport::TaggedLogging.new(self)
        logger.formatter.extend LocalTagStorage
        logger.push_tags(*formatter.current_tags, *tags)
        logger
      end
    end

    def flush
      clear_tags!
      super if defined?(super)
    end
  end
end
