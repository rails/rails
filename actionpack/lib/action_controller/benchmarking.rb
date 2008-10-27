require 'benchmark'

module ActionController #:nodoc:
  # The benchmarking module times the performance of actions and reports to the logger. If the Active Record
  # package has been included, a separate timing section for database calls will be added as well.
  module Benchmarking #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Log and benchmark the workings of a single block and silence whatever logging that may have happened inside it 
      # (unless <tt>use_silence</tt> is set to false).
      #
      # The benchmark is only recorded if the current level of the logger matches the <tt>log_level</tt>, which makes it
      # easy to include benchmarking statements in production software that will remain inexpensive because the benchmark
      # will only be conducted if the log level is low enough.
      def benchmark(title, log_level = Logger::DEBUG, use_silence = true)
        if logger && logger.level == log_level
          result = nil
          seconds = Benchmark.realtime { result = use_silence ? silence { yield } : yield }
          logger.add(log_level, "#{title} (#{('%.1f' % (seconds * 1000))}ms)")
          result
        else
          yield
        end
      end

      # Silences the logger for the duration of the block.
      def silence
        old_logger_level, logger.level = logger.level, Logger::ERROR if logger
        yield
      ensure
        logger.level = old_logger_level if logger
      end
    end

    private

    def log_benchmarks
      return unless logger

      seconds = [ @_runtime[:perform_action], 0.0001 ].max
      logging_view = @_runtime.has_key?(:render)
      logging_active_record = Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?

      log_message  = "Completed in #{sprintf("%.0f", seconds * 1000)}ms"

      if logging_view || logging_active_record
        log_message << " ("
        log_message << view_runtime if logging_view

        if logging_active_record
          log_message << ", " if logging_view
          log_message << active_record_runtime + ")"
        else
          ")"
        end
      end

      log_message << " | #{headers["Status"]}"
      log_message << " [#{complete_request_uri rescue "unknown"}]"

      logger.info(log_message)
      response.headers["X-Runtime"] = "#{sprintf("%.0f", seconds * 1000)}ms"
    end

    def view_runtime
      "View: %.0f" % (@_runtime[:render] * 1000)
    end

    def active_record_runtime
      db_runtime = ActiveRecord::Base.connection.reset_runtime

      if @_runtime[:db_before_render]
        db_runtime += @_runtime[:db_before_render]
        db_runtime += @_runtime[:db_after_render]
      end

      "DB: %.0f" % (db_runtime * 1000)
    end

    def log_render_benchmark
      return unless logger

      if @_runtime.has_key?(:db_before_render)
        @_runtime[:db_after_render] = ActiveRecord::Base.connection.reset_runtime
        @_runtime[:render] -= @_runtime[:db_after_render]
      end
    end

    def reset_db_runtime
      if logger && Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
        @_runtime[:db_before_render] = ActiveRecord::Base.connection.reset_runtime
      end
    end
  end
end
