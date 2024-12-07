# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
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
    class TagProcessor # :nodoc:
      def call(msg, logger)
        if logger.formatter.nil?
          logger.formatter ||= Logger::SimpleFormatter.new
        end

        tag_stack.format_message(msg)
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

    # Returns an `ActiveSupport::Logger` that has already been wrapped with tagged logging concern.
    def self.logger(*args, **kwargs)
      new ActiveSupport::Logger.new(*args, **kwargs)
    end

    def self.new(logger) # :nodoc:
      # Workaround for https://bugs.ruby-lang.org/issues/20250
      # Can be removed when Ruby 3.4 is the least supported version.
      logger.formatter.object_id if logger.formatter.is_a?(Proc)

      if logger.is_a?(TaggedLogging)
        logger.clone
      else
        logger.extend(TaggedLogging)
      end
    end

    def self.extended(base)
      base.tag_processor = TagProcessor.new
      base.extend(ActiveSupport::LogProcessor)

      base.processors << base.tag_processor
    end

    def initialize_clone(_)
      self.tag_processor = TagProcessor.new
      self.processors = [tag_processor]

      super
    end

    delegate :push_tags, :pop_tags, :clear_tags!, to: :tag_processor
    attr_accessor :tag_processor

    def tagged(*tags)
      if block_given?
        tag_processor.tagged(*tags) { yield(self) }
      else
        logger = clone
        logger.tag_processor.extend(LocalTagStorage)
        logger.tag_processor.push_tags(*tag_processor.current_tags, *tags)

        logger
      end
    end

    def flush
      clear_tags!
      super if defined?(super)
    end
  end
end
