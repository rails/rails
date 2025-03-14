# frozen_string_literal: true

module ActiveSupport
  class IsolatedExecutionState # :nodoc:
    @isolation_level = :thread

    class << self
      attr_reader :isolation_level

      def isolation_level=(level)
        return if level == @isolation_level

        unless %i(thread fiber).include?(level)
          raise ArgumentError, "isolation_level must be `:thread` or `:fiber`, got: `#{level.inspect}`"
        end

        clear if @instance
        @isolation_level = level
        @instance = nil
      end

      def instance
        @instance ||= case isolation_level
        when :thread; ThreadIsolatedExecutionState.new
        when :fiber; FiberIsolatedExecutionState.new
        end
      end

      delegate :[], :[]=, :key?, :delete, :clear, :context, :share_with, :scope, to: :instance
    end

    def [](key)
      if (state = context.active_support_execution_state)
        state[key]
      end
    end

    def []=(key, value)
      state = (context.active_support_execution_state ||= {})
      state[key] = value
    end

    def key?(key)
      context.active_support_execution_state&.key?(key)
    end

    def delete(key)
      context.active_support_execution_state&.delete(key)
    end

    def clear
      context.active_support_execution_state&.clear
    end

    def context
      scope.current
    end

    def share_with(other)
      # Action Controller streaming spawns a new thread and copy thread locals.
      # We do the same here for backward compatibility, but this is very much a hack
      # and streaming should be rethought.
      context.active_support_execution_state = other.active_support_execution_state.dup
    end
  end

  class ThreadIsolatedExecutionState < IsolatedExecutionState
    Thread.attr_accessor :active_support_execution_state

    def scope
      Thread
    end

    def isolation_level
      :thread
    end
  end

  class FiberIsolatedExecutionState < IsolatedExecutionState
    Fiber.attr_accessor :active_support_execution_state

    def scope
      Fiber
    end

    def isolation_level
      :fiber
    end
  end
end
