# frozen_string_literal: true

require "weakref"

module ActiveSupport
  # This module provides an internal implementation to track descendants
  # which is faster than iterating through ObjectSpace.
  module DescendantsTracker
    @@direct_descendants = {}

    class << self
      def direct_descendants(klass)
        descendants = @@direct_descendants[klass]
        descendants ? descendants.to_a : []
      end

      def descendants(klass)
        arr = []
        accumulate_descendants(klass, arr)
        arr
      end

      def clear
        if defined? ActiveSupport::Dependencies
          @@direct_descendants.each do |klass, descendants|
            if Dependencies.autoloaded?(klass)
              @@direct_descendants.delete(klass)
            else
              descendants.reject! { |v| Dependencies.autoloaded?(v) }
            end
          end
        else
          @@direct_descendants.clear
        end
      end

      # This is the only method that is not thread safe, but is only ever called
      # during the eager loading phase.
      def store_inherited(klass, descendant)
        (@@direct_descendants[klass] ||= DescendantsArray.new) << descendant
      end

      private

        def accumulate_descendants(klass, acc)
          if direct_descendants = @@direct_descendants[klass]
            direct_descendants.each do |direct_descendant|
              acc << direct_descendant
              accumulate_descendants(direct_descendant, acc)
            end
          end
        end
    end

    def inherited(base)
      DescendantsTracker.store_inherited(self, base)
      super
    end

    def direct_descendants
      DescendantsTracker.direct_descendants(self)
    end

    def descendants
      DescendantsTracker.descendants(self)
    end

    # DescendantsArray is an array that contains weak references to classes.
    class DescendantsArray # :nodoc:
      include Enumerable

      def initialize
        @refs = []
      end

      def initialize_copy(orig)
        @refs = @refs.dup
      end

      def <<(klass)
        cleanup!
        @refs << WeakRef.new(klass)
      end

      def each
        @refs.each do |ref|
          yield ref.__getobj__
        rescue WeakRef::RefError
        end
      end

      def refs_size
        @refs.size
      end

      def cleanup!
        @refs.delete_if { |ref| !ref.weakref_alive? }
      end

      def reject!
        @refs.reject! do |ref|
          yield ref.__getobj__
        rescue WeakRef::RefError
          true
        end
      end
    end
  end
end
