# frozen_string_literal: true

require "active_support/execution_wrapper"

module ActiveSupport
  class Executor < ExecutionWrapper
    @context_changed_callbacks = []

    class << self
      # TODO: doc
      def set_context(**options)
        context = mutable_context

        keys = options.keys
        previous_context = keys.zip(context.values_at(*keys)).to_h
        context.merge!(options.symbolize_keys)
        run_context_changed_callbacks
        if block_given?
          begin
            yield
          ensure
            context.merge!(previous_context)
            run_context_changed_callbacks
          end
        end
      end

      def on_context_changed(&block)
        @context_changed_callbacks << block
      end

      def clear_context
        mutable_context.clear
        run_context_changed_callbacks
      end

      # TODO: doc
      def context
        mutable_context.dup
      end

      private
        def run_context_changed_callbacks
          @context_changed_callbacks.each(&:call)
        end

        def mutable_context
          Thread.current.thread_variable_get(:active_support_executor_context) ||
            Thread.current.thread_variable_set(:active_support_executor_context, {})
        end
    end

    to_complete { Executor.clear_context }
  end
end
