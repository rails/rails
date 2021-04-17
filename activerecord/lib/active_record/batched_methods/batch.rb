# frozen_string_literal: true

require "active_record/batched_methods/type_mismatch"

module ActiveRecord::BatchedMethods
  # Represents a batch of things that will be preloaded together
  class Batch # :nodoc:
    def initialize(klass)
      @klass = klass
      @entries = Set.new
      @result_sets = {}
    end

    def add(entry)
      unless entry.is_a?(@klass)
        raise TypeMismatch.new("Cannot add object of type #{entry.class} to batch of #{@klass}")
      end

      @entries << entry
    end

    def result_for(name, args, entry)
      results = result_set_for(name, args, entry)
      results = perform_for(name, args, entry) unless results

      results[entry]
    end

    private
      # Get the hash that contains the result for a given entry.
      #
      # Note: It's important to maintain seprate hashes here instead of merging
      # since the hash _may_ be defined using Hash#default_proc
      def result_set_for(name, args, entry)
        @result_sets.dig(name, args, entry)
      end

      # Perform the batched method for the given name & entry
      def perform_for(name, args, entry)
        # Determine the slice to run which is either all, or an appropriate
        # slice containing the given entry
        method = @klass.batched_methods.fetch(name)
        batch_size = method.batch_size
        slice = batch_size ?
          @entries.each_slice(batch_size).detect { |b| b.include?(entry) } :
          @entries

        # Call the method with the slice and add the appropriate references to @result_sets
        slice_results = method.call(slice, *args)
        slice.each do |object|
          @result_sets[name] ||= {}
          @result_sets[name][args] ||= {}
          @result_sets[name][args][object] = slice_results
        end

        slice_results
      end
  end
end
