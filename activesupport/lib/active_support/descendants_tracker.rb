# frozen_string_literal: true

module ActiveSupport
  # This module provides an internal implementation to track descendants
  # which is faster than iterating through ObjectSpace.
  module DescendantsTracker
    @@direct_descendants = {}

    class << self
      def direct_descendants(klass)
        @@direct_descendants[klass] || []
      end

      def descendants(klass)
        arr = []
        accumulate_descendants(klass, arr)
        arr
      end

      def clear
        if defined? ActiveSupport::Dependencies
          @@direct_descendants.each do |klass, descendants|
            if ActiveSupport::Dependencies.autoloaded?(klass)
              @@direct_descendants.delete(klass)
            else
              descendants.reject! { |v| ActiveSupport::Dependencies.autoloaded?(v) }
            end
          end
        else
          @@direct_descendants.clear
        end
      end

      # This is the only method that is not thread safe, but is only ever called
      # during the eager loading phase.
      def store_inherited(klass, descendant)
        (@@direct_descendants[klass] ||= []) << descendant
      end

      private
      def accumulate_descendants(klass, acc)
        if direct_descendants = @@direct_descendants[klass]
          acc.concat(direct_descendants)
          direct_descendants.each { |direct_descendant| accumulate_descendants(direct_descendant, acc) }
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
  end
end
