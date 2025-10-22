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
  #
  # WARNING: This method is unreliable in certain situations:
  #
  # * It only returns classes that have already been loaded. When using
  #   autoloading, classes that haven't been referenced yet won't appear
  #   in the results, even if their files exist in the codebase.
  #
  # * The results are non-deterministic with regards to Garbage Collection.
  #   If you use this method in tests where classes are dynamically defined,
  #   GC is unpredictable about when those classes are cleaned up and removed.
  #
  # Consider these limitations carefully when using this method, especially in
  # production code.
  def descendants
    subclasses.concat(subclasses.flat_map(&:descendants))
  end

  prepend ActiveSupport::DescendantsTracker::ReloadedClassesFiltering
end
