require 'active_support/dependencies'

module ActiveSupport
  # This module provides an internal implementation to track descendants
  # which is faster than iterating through ObjectSpace.
  module DescendantsTracker
    @@direct_descendants = Hash.new { |h, k| h[k] = [] }

    def self.direct_descendants(klass)
      @@direct_descendants[klass]
    end

    def self.descendants(klass)
      @@direct_descendants[klass].inject([]) do |descendants, _klass|
        descendants << _klass
        descendants.concat _klass.descendants
      end
    end

    def self.clear
      @@direct_descendants.each do |klass, descendants|
        if ActiveSupport::Dependencies.autoloaded?(klass)
          @@direct_descendants.delete(klass)
        else
          descendants.reject! { |v| ActiveSupport::Dependencies.autoloaded?(v) }
        end
      end
    end

    def inherited(base)
      self.direct_descendants << base
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
