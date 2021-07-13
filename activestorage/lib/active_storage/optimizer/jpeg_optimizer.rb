# frozen_string_literal: true

module ActiveStorage
  #
  # Performs lossy compression on jpg/jpeg images.
  #
  # Options below are available to all jpeg encoders
  # - strip               : Removes all metadata;
  # - quality             : 85 is the recommended value by the PageSpeed apache module;
  # - interlace           : Writes an interlaced JPEG, which gives the impression of faster loading in slow connections;
  # - sampling_factor     : Reduced color detail, smaller file sizes;
  # - colorspace          : Ensure compatibility when performing transformations;
  #
  # Options below are available only if vips/image magick where compiled against {mozjpeg}[https://github.com/mozilla/mozjpeg].
  # - optimize_coding     : Slightly slower processing, slightly smaller file sizes;
  # - optimize_scans      : Slower processing, slightly smaller files sizes;
  # - trellis_quant       : Slower processing, smaller file sizes;
  # - quant_table         : 3 produces good results in the default quality setting, but causes banding at high compression.
  # - overshoot_deringing : Reduces ringing artifacts, specially in areas where black text appears on white background.
  #
  # Vips will ignore them if mozjpeg is not available. ImageMagick will apply them automatically if it is.
  #
  # For a more complete explanation of each option check the {vips}[https://libvips.github.io/libvips/API/current/VipsForeignSave.html#vips-jpegsave] and {ImageMagick}[https://imagemagick.org/script/command-line-options.php] documentation.
  class Optimizer::JpegOptimizer < Optimizer
    def self.accept?(format)
      %w[ jpg jpeg ].include?(format.to_s)
    end

    def transformations
      if vips?
        { format: "jpg", saver: { strip: true, quality: 85, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3, optimize_scans: true, overshoot_deringing: true } }
      else
        { format: "jpg", saver: { strip: true, quality: 85, interlace: "JPEG", sampling_factor: "4:2:0", colorspace: "sRGB" } }
      end
    end
  end
end
