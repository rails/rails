# frozen_string_literal: true

module ActiveSupport
  module IsolatedExecutionState # :nodoc:
    @isolation_level = nil

    Thread.attr_accessor :active_support_execution_state
    Fiber.attr_accessor :active_support_execution_state

    class << self
      attr_reader :isolation_level, :scope

      def isolation_level=(level)
        return if level == @isolation_level

        unless %i(thread fiber).include?(level)
          raise ArgumentError, "isolation_level must be `:thread` or `:fiber`, got: `#{level.inspect}`"
        end

        clear if @isolation_level

        @scope =
          case level
          when :thread; Thread
          when :fiber; Fiber
          end

        @isolation_level = level
      end

      def unique_id
        self[:__id__] ||= Object.new
      end

      def [](key)
        if state = @scope.current.active_support_execution_state
          state[key]
        end
      end

      def []=(key, value)
        state = (@scope.current.active_support_execution_state ||= {})
        state[key] = value
      end

      def key?(key)
        @scope.current.active_support_execution_state&.key?(key)
      end

      def delete(key)
        @scope.current.active_support_execution_state&.delete(key)
      end

      def clear
        @scope.current.active_support_execution_state&.clear
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

    self.isolation_level = :thread
  end
end
