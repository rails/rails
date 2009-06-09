module AbstractController
  module Benchmarker
    extend ActiveSupport::Concern

    include Logger

    module ClassMethods
      # Execute the passed in block, timing the duration of the block in ms.
      #
      # ==== Parameters
      # title<#to_s>:: The title of block to benchmark
      # log_level<Integer>:: A valid log level. Defaults to Logger::DEBUG
      # use_silence<TrueClass, FalseClass>:: Whether or not to silence the
      #   logger for the duration of the block.
      #
      # ==== Returns
      # Object:: The result of the block
      def benchmark(title, log_level = ::Logger::DEBUG, use_silence = true)
        if logger && logger.level >= log_level
          result = nil
          ms = Benchmark.ms { result = use_silence ? silence { yield } : yield }
          logger.add(log_level, "#{title} (#{('%.1f' % ms)}ms)")
          result
        else
          yield
        end
      end

      # Silences the logger for the duration of the block.
      def silence
        old_logger_level, logger.level = logger.level, ::Logger::ERROR if logger
        yield
      ensure
        logger.level = old_logger_level if logger
      end
    end
  end
end
