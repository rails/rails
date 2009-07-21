require 'active_support/core_ext/logger'

module AbstractController
  module Logger
    extend ActiveSupport::Concern

    # A class that allows you to defer expensive processing
    # until the logger actually tries to log. Otherwise, you are
    # forced to do the processing in advance, and send the
    # entire processed String to the logger, which might
    # just discard the String if the log level is too low.
    #
    # TODO: Require that Rails loggers accept a block.
    class DelayedLog
      def initialize(&blk)
        @blk = blk
      end

      def to_s
        @blk.call
      end
      alias to_str to_s
    end

    included do
      cattr_accessor :logger
    end

    # Override process_action in the AbstractController::Base
    # to log details about the method.
    def process_action(action)
      super

      if logger
        log = DelayedLog.new do
          "\n\nProcessing #{self.class.name}\##{action_name} " \
          "to #{request.formats} " \
          "(for #{request_origin}) [#{request.method.to_s.upcase}]"
        end

        logger.info(log)
      end
    end

  private
    def request_origin
      # this *needs* to be cached!
      # otherwise you'd get different results if calling it more than once
      @request_origin ||= "#{request.remote_ip} at #{Time.now.to_s(:db)}"
    end
  end
end
