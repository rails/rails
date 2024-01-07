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
          messages << ("ActiveRecord: %.1fms" % db_runtime.to_f) if db_runtime
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
            db_rt_before_render = ActiveRecord::RuntimeRegistry.reset
            self.db_runtime = (db_runtime || 0) + db_rt_before_render
            runtime = super
            queries_rt = ActiveRecord::RuntimeRegistry.sql_runtime - ActiveRecord::RuntimeRegistry.async_sql_runtime
            db_rt_after_render = ActiveRecord::RuntimeRegistry.reset
            self.db_runtime += db_rt_after_render
            runtime - queries_rt
          else
            super
          end
        end

        def append_info_to_payload(payload)
          super

          payload[:db_runtime] = (db_runtime || 0) + ActiveRecord::RuntimeRegistry.reset
        end
    end
  end
end
