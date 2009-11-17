require 'active_support/core_ext/logger'
require 'active_support/benchmarkable'

module AbstractController
  module Logger
    extend ActiveSupport::Concern

    included do
      cattr_accessor :logger
      extend ActiveSupport::Benchmarkable
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
      result = ActiveSupport::Notifications.instrument(:process_action,
                :controller => self, :action => action) do
        super
      end

      if logger
        log = DelayedLog.new do
          "\n\nProcessing #{self.class.name}\##{action_name} " \
          "to #{request.formats} (for #{request_origin}) " \
          "[#{request.method.to_s.upcase}]"
        end

        logger.info(log)
      end

      result
    end

  private
    # Returns the request origin with the IP and time. This needs to be cached,
    # otherwise we would get different results for each time it calls.
    def request_origin
      @request_origin ||= "#{request.remote_ip} at #{Time.now.to_s(:db)}"
    end
  end
end
