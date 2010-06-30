require 'active_support/dependencies'

module ActiveSupport
  # This module provides an internal implementation to track descendants
  # which is faster than iterating through ObjectSpace.
  module DescendantsTracker
    @@descendants = Hash.new { |h, k| h[k] = [] }

    def self.descendants
      @@descendants
    end

    def self.clear
      @@descendants.each do |klass, descendants|
        if ActiveSupport::Dependencies.autoloaded?(klass)
          @@descendants.delete(klass)
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
      @@descendants[self]
    end

    def descendants
      @@descendants[self].inject([]) do |descendants, klass|
        descendants << klass
        descendants.concat klass.descendants
      end
    end
  end
end