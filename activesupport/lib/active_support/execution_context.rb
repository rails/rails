# frozen_string_literal: true

module ActiveSupport
  module ExecutionContext # :nodoc:
    class Record
      attr_reader :store, :current_attributes_instances

      def initialize
        @store = {}
        @current_attributes_instances = {}
        @stack = []
      end

      def push
        @stack << @store << @current_attributes_instances
        @store = {}
        @current_attributes_instances = {}
        self
      end

      def pop
        @current_attributes_instances = @stack.pop
        @store = @stack.pop
        self
      end
    end

    @after_change_callbacks = []

    # Execution context nesting should only legitimately happen during test
    # because the test case itself is wrapped in an executor, and it might call
    # into a controller or job which should be executed with their own fresh context.
    # However in production this should never happen, and for extra safety we make sure to
    # fully clear the state at the end of the request or job cycle.
    @nestable = false

    class << self
      attr_accessor :nestable

      def after_change(&block)
        @after_change_callbacks << block
      end

      # Updates the execution context. If a block is given, it resets the provided keys to their
      # previous value once the block exits.
      def set(**options)
        options.symbolize_keys!
        keys = options.keys

        store = record.store

        previous_context = if block_given?
          keys.zip(store.values_at(*keys)).to_h
        end

        store.merge!(options)
        @after_change_callbacks.each(&:call)

        if block_given?
          begin
            yield
          ensure
            store.merge!(previous_context)
            @after_change_callbacks.each(&:call)
          end
        end
      end

      def []=(key, value)
        record.store[key.to_sym] = value
        @after_change_callbacks.each(&:call)
      end

      def to_h
        record.store.dup
      end

      def push
        if @nestable
          record.push
        else
          clear
        end
        self
      end

      def pop
        if @nestable
          record.pop
        else
          clear
        end
        self
      end

      def clear
        IsolatedExecutionState[:active_support_execution_context] = nil
      end

      def current_attributes_instances
        record.current_attributes_instances
      end

      private
        def record
          IsolatedExecutionState[:active_support_execution_context] ||= Record.new
        end
    end
  end
end
