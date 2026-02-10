# frozen_string_literal: true

require "concurrent/map"

module ActiveRecord
  module Associations
    # = Active Record Counter Cache Registry
    #
    # This module provides a registry for counter cache columns that need to be
    # added to a class that hasn't been loaded yet. When a belongs_to association
    # with counter_cache: true is defined, and the associated class hasn't been
    # loaded yet, the counter cache column is registered here. When the associated
    # class is loaded, the pending counter cache columns are added to it.
    module CounterCacheRegistry
      extend self

      def registry
        @registry ||= Concurrent::Map.new
      end

      # Register a counter cache column for a class that hasn't been loaded yet.
      # @param class_name [String] The name of the class to register the counter cache column for.
      # @param cache_column [String] The name of the counter cache column.
      def register(class_name, cache_column)
        registry.compute_if_absent(class_name) { [] }
        registry[class_name] << cache_column
      end

      # Process pending counter cache columns for a class that has just been loaded.
      # @param klass [Class] The class to process pending counter cache columns for.
      def process_pending(klass)
        class_name = klass.name
        return unless class_name && registry.key?(class_name)

        cache_columns = registry.delete(class_name)
        return if cache_columns.empty?

        klass._counter_cache_columns |= cache_columns if klass.respond_to?(:_counter_cache_columns)
      end

      def clear
        registry.clear
      end
    end
  end
end
