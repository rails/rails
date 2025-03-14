# frozen_string_literal: true

module ActiveSupport
  class ExecutionContext # :nodoc:
    class << self
      def instance
        @instance ||= new(IsolatedExecutionState)
      end

      delegate :after_change, :set, :to_h, :clear, :[]=, to: :instance
    end

    def initialize(isolated_execution_state)
      @isolated_execution_state = isolated_execution_state
      @after_change_callbacks = []
    end

    def after_change(&block)
      @after_change_callbacks << block
    end

    def set(**options)
      options.symbolize_keys!
      keys = options.keys

      previous_context = keys.zip(store.values_at(*keys)).to_h

      store.merge!(options)
      notify_callbacks

      if block_given?
        begin
          yield
        ensure
          store.merge!(previous_context)
          notify_callbacks
        end
      end
    end

    def []=(key, value)
      store[key.to_sym] = value
      notify_callbacks
    end

    def to_h
      store.dup
    end

    def clear
      store.clear
    end

    private
      def notify_callbacks
        @after_change_callbacks.each(&:call)
      end

      def store
        @isolated_execution_state[:active_support_execution_context] ||= {}
      end
  end
end
