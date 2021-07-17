# frozen_string_literal: true

require "active_record/log_subscriber"

module ActiveRecord
  module Railties # :nodoc:
    module JobRuntime #:nodoc:
      private
        def instrument(operation, payload = {}, &block)
          if operation == :perform && block
            db_runtime_before = ActiveRecord::LogSubscriber.runtime
            super(operation, payload) do
              block.call
              payload[:db_runtime] = ActiveRecord::LogSubscriber.runtime - db_runtime_before
            end
          else
            super
          end
        end
    end
  end
end
