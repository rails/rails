require 'active_support/core_ext/benchmark'

module ActionController #:nodoc:
  # The benchmarking module times the performance of actions and reports to the logger. If the Active Record
  # package has been included, a separate timing section for database calls will be added as well.
  module Benchmarking #:nodoc:
    extend ActiveSupport::Concern

    protected
      def render(*args, &block)
        if logger
          if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
            db_runtime = ActiveRecord::Base.connection.reset_runtime
          end

          render_output = nil
          @view_runtime = Benchmark.ms { render_output = super }

          if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
            @db_rt_before_render = db_runtime
            @db_rt_after_render = ActiveRecord::Base.connection.reset_runtime
            @view_runtime -= @db_rt_after_render
          end

          render_output
        else
          super
        end
      end

    private
      def process_action(*args)
        if logger
          ms = [Benchmark.ms { super }, 0.01].max
          logging_view          = defined?(@view_runtime)
          logging_active_record = Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?

          log_message  = 'Completed in %.0fms' % ms

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

          log_message << " | #{response.status}"
          log_message << " [#{complete_request_uri rescue "unknown"}]"

          logger.info(log_message)
          response.headers["X-Runtime"] = "%.0f" % ms
        else
          super
        end
      end

      def view_runtime
        "View: %.0f" % @view_runtime
      end

      def active_record_runtime
        db_runtime = ActiveRecord::Base.connection.reset_runtime
        db_runtime += @db_rt_before_render if @db_rt_before_render
        db_runtime += @db_rt_after_render if @db_rt_after_render
        "DB: %.0f" % db_runtime
      end
  end
end
