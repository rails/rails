require 'benchmark'

module ActionController #:nodoc:
  # The benchmarking module times the performance of actions and reports to the logger. If the Active Record
  # package has been included, a separate timing section for database calls will be added as well.
  module Benchmarking #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)

      base.class_eval do
        alias_method_chain :perform_action, :benchmark
        alias_method_chain :render, :benchmark
      end
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
          logger.add(log_level, "#{title} (#{'%.5f' % seconds})")
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

    def render_with_benchmark(options = nil, deprecated_status = nil, &block)
      unless logger
        render_without_benchmark(options, deprecated_status, &block)
      else
        db_runtime = ActiveRecord::Base.connection.reset_runtime if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?

        render_output = nil
        @rendering_runtime = Benchmark::measure{ render_output = render_without_benchmark(options, deprecated_status, &block) }.real

        if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
          @db_rt_before_render = db_runtime
          @db_rt_after_render = ActiveRecord::Base.connection.reset_runtime
          @rendering_runtime -= @db_rt_after_render
        end

        render_output
      end
    end    

    def perform_action_with_benchmark
      unless logger
        perform_action_without_benchmark
      else
        runtime = [Benchmark::measure{ perform_action_without_benchmark }.real, 0.0001].max
        log_message  = "Completed in #{sprintf("%.5f", runtime)} (#{(1 / runtime).floor} reqs/sec)"
        log_message << rendering_runtime(runtime) if defined?(@rendering_runtime)
        log_message << active_record_runtime(runtime) if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
        log_message << " | #{headers["Status"]}"
        log_message << " [#{complete_request_uri rescue "unknown"}]"
        logger.info(log_message)
      end
    end
    
    private
      def rendering_runtime(runtime)
        " | Rendering: #{sprintf("%.5f", @rendering_runtime)} (#{sprintf("%d", (@rendering_runtime * 100) / runtime)}%)"
      end

      def active_record_runtime(runtime)
        db_runtime    = ActiveRecord::Base.connection.reset_runtime
        db_runtime    += @db_rt_before_render if @db_rt_before_render
        db_runtime    += @db_rt_after_render if @db_rt_after_render
        db_percentage = (db_runtime * 100) / runtime
        " | DB: #{sprintf("%.5f", db_runtime)} (#{sprintf("%d", db_percentage)}%)"
      end
  end
end
