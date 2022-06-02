# frozen_string_literal: true

module ActiveRecord
  # This is a thread locals registry for Active Record. For example:
  #
  #   ActiveRecord::RuntimeRegistry.sql_runtime
  #
  # returns the connection handler local to the current unit of execution (either thread of fiber).
  module RuntimeRegistry # :nodoc:
    extend self

    def sql_runtime
      ActiveSupport::IsolatedExecutionState[:active_record_sql_runtime]
    end

    def sql_runtime=(runtime)
      ActiveSupport::IsolatedExecutionState[:active_record_sql_runtime] = runtime
    end
  end
end
