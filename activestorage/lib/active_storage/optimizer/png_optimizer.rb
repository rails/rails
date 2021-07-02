# frozen_string_literal: true

module ActiveStorage
  #
  # Does not apply any transformations to blobs that are web images.
  # Converts blobs that aren't web images into PNGs.
  #
  class Optimizer::PngOptimizer < Optimizer
    def self.accept?(format)
      format.to_s == "png"
    end

    def transformations
      if vips?
        { format: "png", saver: { strip: true, compression: 9 } }
      else
        { format: "png", saver: { strip: true, quality: 75 } }
      end
    end
  end
end
