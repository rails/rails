module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Range #:nodoc:
      # Check if Ranges overlap.
      module Overlaps
        def overlaps?(other)
          include?(other.first) || other.include?(first)
        end
      end
    end
  end
end
