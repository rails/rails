# frozen_string_literal: true

module ActiveStorage
  #
  # Does not apply any transformations to blobs that are web images.
  # Converts blobs that aren't web images into PNGs.
  #
  class Optimizer::WebImageOptimizer < Optimizer
    def self.accept?(format)
      true
    end

    def transformations
      { format: default_variant_format }
    end

    private
      def default_variant_format
        if blob.send(:web_image?)
          blob.send(:format) || :png
        else
          :png
        end
      end
  end
end
