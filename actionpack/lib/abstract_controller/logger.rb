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
  end
end
