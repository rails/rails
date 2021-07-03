# frozen_string_literal: true

module ActiveStorage
  #
  # Performs lossless compression on png images.
  #
  # Vips uses "compression" to indicate how much effort it should spend to compress the image.
  # Higher values increaase processing time and reduce file sizes. Ranges from 0 to 9.
  #
  # ImageMagick uses "quality", but it works differently from JPEG quality. 75 is the default
  # and means compression level of 7 with adaptive PNG filtering.
  #
  # For a more complete explanation of each option check the {vips}[https://libvips.github.io/libvips/API/current/VipsForeignSave.html#vips-pngsave] and {ImageMagick}[https://imagemagick.org/script/command-line-options.php#quality] documentation.
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
