# frozen_string_literal: true

require "weakref"
require "active_support/ruby_features"

module ActiveSupport
  # This module provides an internal implementation to track descendants
  # which is faster than iterating through ObjectSpace.
  module DescendantsTracker
    class << self
      def direct_descendants(klass)
        ActiveSupport::Deprecation.warn(<<~MSG)
          ActiveSupport::DescendantsTracker.direct_descendants is deprecated and will be removed in Rails 7.1.
          Use ActiveSupport::DescendantsTracker.subclasses instead.
        MSG
        subclasses(klass)
      end
    end

    if RubyFeatures::CLASS_DESCENDANTS
      class << self
        def subclasses(klass)
          klass.subclasses
        end

        def descendants(klass)
          klass.descendants
        end

        def clear(only: nil) # :nodoc:
          # noop
        end

        def native? # :nodoc:
          true
        end
      end

      unless RubyFeatures::CLASS_SUBCLASSES
        def subclasses
          descendants.select { |descendant| descendant.superclass == self }
        end
      end

      def direct_descendants
        ActiveSupport::Deprecation.warn(<<~MSG)
          ActiveSupport::DescendantsTracker#direct_descendants is deprecated and will be removed in Rails 7.1.
          Use #subclasses instead.
        MSG
        subclasses
      end
    else
      @@direct_descendants = {}

      class << self
        def subclasses(klass)
          descendants = @@direct_descendants[klass]
          descendants ? descendants.to_a : []
        end

        def descendants(klass)
          arr = []
          accumulate_descendants(klass, arr)
          arr
        end

        def clear(only: nil) # :nodoc:
          if only.nil?
            @@direct_descendants.clear
            return
          end

          @@direct_descendants.each do |klass, direct_descendants_of_klass|
            if only.member?(klass)
              @@direct_descendants.delete(klass)
            else
              direct_descendants_of_klass.reject! do |direct_descendant_of_class|
                only.member?(direct_descendant_of_class)
              end
            end
          end
        end

        def native? # :nodoc:
          false
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
        ActiveSupport::Deprecation.warn(<<~MSG)
          ActiveSupport::DescendantsTracker#direct_descendants is deprecated and will be removed in Rails 7.1.
          Use #subclasses instead.
        MSG
        DescendantsTracker.subclasses(self)
      end

      def subclasses
        DescendantsTracker.subclasses(self)
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
          @refs << WeakRef.new(klass)
        end

        def each
          @refs.reject! do |ref|
            yield ref.__getobj__
            false
          rescue WeakRef::RefError
            true
          end
          self
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
end
