# frozen_string_literal: true

require "active_support/descendants_tracker"

class Class
  # Returns an array with all classes that are < than its receiver.
  #
  #   class C; end
  #   C.descendants # => []
  #
  #   class B < C; end
  #   C.descendants # => [B]
  #
  #   class A < B; end
  #   C.descendants # => [B, A]
  #
  #   class D < C; end
  #   C.descendants # => [B, A, D]
  def descendants
    subclasses.concat(subclasses.flat_map(&:descendants))
  end

  prepend ActiveSupport::DescendantsTracker::ReloadedClassesFiltering
end
