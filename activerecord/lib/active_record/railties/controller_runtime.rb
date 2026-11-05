# frozen_string_literal: true

require "active_support/core_ext/module/attr_internal"
require "active_record/runtime_registry"

module ActiveRecord
  module Railties # :nodoc:
    module ControllerRuntime # :nodoc:
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc:
        def log_process_action(payload)
          messages, db_runtime = super, payload[:db_runtime]

          if db_runtime
            queries_count = payload[:queries_count] || 0
            cached_queries_count = payload[:cached_queries_count] || 0
            messages << ("ActiveRecord: %.1fms (%d %s, %d cached)" % [db_runtime.to_f, queries_count,
                                                                      "query".pluralize(queries_count), cached_queries_count])
          end

          messages
        end
      end

      def initialize(...) # :nodoc:
        super
        self.db_runtime = nil
      end

      private
        attr_internal :db_runtime

        def process_action(action, *args)
          # We also need to reset the runtime before each action
          # because of queries in middleware or in cases we are streaming
          # and it won't be cleaned up by the method below.
          ActiveRecord::RuntimeRegistry.reset
          super
        end

        def cleanup_view_runtime
          if logger && logger.info?
            runtime_stats = ActiveRecord::RuntimeRegistry.stats
            db_rt_before_render = runtime_stats.reset_runtimes
            self.db_runtime = (db_runtime || 0) + db_rt_before_render

            runtime = super

            queries_rt = runtime_stats.sql_runtime - runtime_stats.async_sql_runtime
            db_rt_after_render = runtime_stats.reset_runtimes
            self.db_runtime += db_rt_after_render
            runtime - queries_rt
          else
            super
          end
        end

        def append_info_to_payload(payload)
          super

          runtime_stats = ActiveRecord::RuntimeRegistry.stats
          payload[:db_runtime] = (db_runtime || 0) + runtime_stats.sql_runtime
          payload[:queries_count] = runtime_stats.queries_count
          payload[:cached_queries_count] = runtime_stats.cached_queries_count
          runtime_stats.reset
        end
    end
  end
end
