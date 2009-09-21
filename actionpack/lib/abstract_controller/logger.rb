require 'active_support/core_ext/logger'

module AbstractController
  module Logger
    extend ActiveSupport::Concern

    included do
      cattr_accessor :logger
    end

    module ClassMethods #:nodoc:
      # Logs a message appending the value measured.
      def log_with_time(message, time, log_level=::Logger::DEBUG)
        return unless logger && logger.level >= log_level
        logger.add(log_level, "#{message} (%.1fms)" % time)
      end

      # Silences the logger for the duration of the block.
      def silence
        old_logger_level, logger.level = logger.level, ::Logger::ERROR if logge
        yield
      ensure
        logger.level = old_logger_level if logger
      end
    end

    # A class that allows you to defer expensive processing
    # until the logger actually tries to log. Otherwise, you are
    # forced to do the processing in advance, and send the
    # entire processed String to the logger, which might
    # just discard the String if the log level is too low.
    #
    # TODO: Require that Rails loggers accept a block.
    class DelayedLog < ActiveSupport::BasicObject
      def initialize(&block)
        @str, @block = nil, block
      end

      def method_missing(*args, &block)
        unless @str
          @str, @block = @block.call, nil
        end
        @str.send(*args, &block)
      end
    end

    # Override process_action in the AbstractController::Base
    # to log details about the method.
    def process_action(action)
      event = ActiveSupport::Orchestra.instrument(:process_action,
                :controller => self, :action => action) do
        super
      end

      if logger
        log = DelayedLog.new do
          "\n\nProcessing #{self.class.name}\##{action_name} " \
          "to #{request.formats} (for #{request_origin}) " \
          "(%.1fms) [#{request.method.to_s.upcase}]" % event.duration
        end

        logger.info(log)
      end

      event.result
    end

  private
    # Returns the request origin with the IP and time. This needs to be cached,
    # otherwise we would get different results for each time it calls.
    def request_origin
      @request_origin ||= "#{request.remote_ip} at #{Time.now.to_s(:db)}"
    end
  end
end
