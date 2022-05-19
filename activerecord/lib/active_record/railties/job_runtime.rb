# frozen_string_literal: true

require "active_record/log_subscriber"

module ActiveRecord
  module Railties # :nodoc:
    module JobRuntime # :nodoc:
      private
        def instrument(operation, payload = {}, &block)
          if operation == :perform && block
            super(operation, payload) do
              db_runtime_before_perform = ActiveRecord::LogSubscriber.runtime
              result = block.call
              payload[:db_runtime] = ActiveRecord::LogSubscriber.runtime - db_runtime_before_perform
              result
            end
          else
            super
          end
        end
    end
  end
end
