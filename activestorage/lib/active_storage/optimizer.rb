# frozen_string_literal: true

module ActiveStorage
  # This is an abstract base class for optimizers, which apply transformations to blob representations.
  # See ActiveStorage::Optimizer::WebImageOptimizer for an example of a concrete subclass.
  class Optimizer
    attr_reader :blob

    # Implement this method in a concrete subclass. Have it return true when given a format from which
    # the optimizer knows the transformations that should be applied.
    def self.accept?(format)
      false
    end

    def initialize(blob)
      @blob = blob
    end

    # Override this method in a concrete subclass. Have it return a Hash of transformations.
    def transformations
      raise NotImplementedError
    end

    private
      def vips?
        ActiveStorage.variant_processor == :vips
      end
  end
end
