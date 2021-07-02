# frozen_string_literal: true

module ActiveStorage
  #
  # Does not apply any transformations to blobs that are web images.
  # Converts blobs that aren't web images into PNGs.
  #
  class Optimizer::JpegOptimizer < Optimizer
    def self.accept?(format)
      %w[ jpg jpeg ].include?(format.to_s)
    end

    def transformations
      if vips?
        { format: "jpg", saver: { strip: true, quality: 80, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 } }
      else
        { format: "jpg", saver: { strip: true, quality: 80, interlace: "JPEG", sampling_factor: "4:2:0", colorspace: "sRGB" } }
      end
    end
  end
end
