# frozen_string_literal: true

require "concurrent/hash"

module ActiveSupport
  class ExecutionContext  # :nodoc:
    module FiberLocal
      def self.extended(base)
        base.instance_variable_set(:@registry, Concurrent::Hash.new.compare_by_identity)
      end

      def current
        @registry[Fiber.current.object_id] ||= new
      end

      def clear
        @registry.delete(Fiber.current.object_id)
        nil
      end

      def clear_all
        @registry.clear
      end
    end

    module ThreadLocal
      def self.extended(base)
        base.instance_variable_set(:@registry, Concurrent::Hash.new.compare_by_identity)
      end

      def current
        @registry[Thread.current.object_id] ||= new
      end

      def clear
        @registry.delete(Thread.current.object_id)
        nil
      end

      def clear_all
        @registry.clear
      end
    end

    module ProcessLocal
      def self.extended(base)
        base.instance_variable_set(:@registry, nil)
      end

      def current
        @registry ||= new
      end

      def clear
        @registry = nil
      end

      def clear_all
        @registry = nil
      end
    end

    ISOLATION_LEVELS = {
      fiber: FiberLocal,
      thread: ThreadLocal,
      process: ProcessLocal,
    }.freeze

    class << self
      attr_reader :isolation_level

      def isolation_level=(level)
        mod = ISOLATION_LEVELS.fetch(level)
        singleton_class.define_method(:current, mod.instance_method(:current))
        singleton_class.define_method(:clear, mod.instance_method(:clear))
        singleton_class.define_method(:clear_all, mod.instance_method(:clear_all))
        mod.extended(self)
        @isolation_level = level
      end

      def define_accessor(name)
        attr_accessor(name)
      end
    end

    self.isolation_level = :fiber
  end
end
