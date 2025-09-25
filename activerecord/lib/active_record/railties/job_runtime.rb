# frozen_string_literal: true

require "active_record/runtime_registry"

module ActiveRecord
  module Railties # :nodoc:
    module JobRuntime # :nodoc:
      def instrument(operation, payload = {}, &block) # :nodoc:
        if operation == :perform && block
          super(operation, payload) do
            db_runtime_before_perform = ActiveRecord::RuntimeRegistry.stats.sql_runtime
            result = block.call
            payload[:db_runtime] = ActiveRecord::RuntimeRegistry.stats.sql_runtime - db_runtime_before_perform
            result
          end
        else
          super
        end
      end
    end
  end
end
