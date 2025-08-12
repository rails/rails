# frozen_string_literal: true

module ActiveSupport
  module Execution # :nodoc:
    # Nesting should only legitimately happen during test because the test case
    # itself is wrapped in an executor, and it might call into a controller or
    # job which should be executed with their own fresh context. However in
    # production this should never happen, and for extra safety we make sure to
    # fully clear the state at the end of the request or job cycle.
    @nestable = false

    class << self
      attr_accessor :nestable

      def [](key)
        current[key]
      end

      def []=(key, value)
        current[key] = value
      end

      def push
        if @nestable
          state << {}
        else
          clear
        end
        self
      end

      def pop
        if @nestable
          state.pop
        else
          clear
        end
        self
      end

      def clear
        IsolatedExecutionState[:active_support_execution] = nil
      end

      private
        def state
          IsolatedExecutionState[:active_support_execution] ||= []
        end

        def current
          state.last || (state << {}).last
        end
    end
  end
end
