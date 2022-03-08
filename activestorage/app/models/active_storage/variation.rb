# frozen_string_literal: true

# A set of transformations that can be applied to a blob to create a variant. This class is exposed via
# the ActiveStorage::Blob#variant method and should rarely be used directly.
#
# In case you do need to use this directly, it's instantiated using a hash of transformations where
# the key is the command and the value is the arguments. Example:
#
#   ActiveStorage::Variation.new(resize: "100x100", monochrome: true, trim: true, rotate: "-90")
#
# You can also combine multiple transformations in one step, e.g. for center-weighted cropping:
#
#   ActiveStorage::Variation.new(combine_options: {
#     resize: "100x100^",
#     gravity: "center",
#     crop: "100x100+0+0",
#   })
#
# A list of all possible transformations is available at https://www.imagemagick.org/script/mogrify.php.
class ActiveStorage::Variation
  attr_reader :transformations

  class UnsupportedImageProcessingMethod < StandardError; end
  class UnsupportedImageProcessingArgument < StandardError; end

  SUPPORTED_IMAGE_PROCESSING_METHODS = [
   "adaptive_blur",
   "adaptive_resize",
   "adaptive_sharpen",
   "adjoin",
   "affine",
   "alpha",
   "annotate",
   "antialias",
   "append",
   "apply",
   "attenuate",
   "authenticate",
   "auto_gamma",
   "auto_level",
   "auto_orient",
   "auto_threshold",
   "backdrop",
   "background",
   "bench",
   "bias",
   "bilateral_blur",
   "black_point_compensation",
   "black_threshold",
   "blend",
   "blue_primary",
   "blue_shift",
   "blur",
   "border",
   "bordercolor",
   "borderwidth",
   "brightness_contrast",
   "cache",
   "canny",
   "caption",
   "channel",
   "channel_fx",
   "charcoal",
   "chop",
   "clahe",
   "clamp",
   "clip",
   "clip_path",
   "clone",
   "clut",
   "coalesce",
   "colorize",
   "colormap",
   "color_matrix",
   "colors",
   "colorspace",
   "colourspace",
   "color_threshold",
   "combine",
   "combine_options",
   "comment",
   "compare",
   "complex",
   "compose",
   "composite",
   "compress",
   "connected_components",
   "contrast",
   "contrast_stretch",
   "convert",
   "convolve",
   "copy",
   "crop",
   "cycle",
   "deconstruct",
   "define",
   "delay",
   "delete",
   "density",
   "depth",
   "descend",
   "deskew",
   "despeckle",
   "direction",
   "displace",
   "dispose",
   "dissimilarity_threshold",
   "dissolve",
   "distort",
   "dither",
   "draw",
   "duplicate",
   "edge",
   "emboss",
   "encoding",
   "endian",
   "enhance",
   "equalize",
   "evaluate",
   "evaluate_sequence",
   "extent",
   "extract",
   "family",
   "features",
   "fft",
   "fill",
   "filter",
   "flatten",
   "flip",
   "floodfill",
   "flop",
   "font",
   "foreground",
   "format",
   "frame",
   "function",
   "fuzz",
   "fx",
   "gamma",
   "gaussian_blur",
   "geometry",
   "gravity",
   "grayscale",
   "green_primary",
   "hald_clut",
   "highlight_color",
   "hough_lines",
   "iconGeometry",
   "iconic",
   "identify",
   "ift",
   "illuminant",
   "immutable",
   "implode",
   "insert",
   "intensity",
   "intent",
   "interlace",
   "interline_spacing",
   "interpolate",
   "interpolative_resize",
   "interword_spacing",
   "kerning",
   "kmeans",
   "kuwahara",
   "label",
   "lat",
   "layers",
   "level",
   "level_colors",
   "limit",
   "limits",
   "linear_stretch",
   "linewidth",
   "liquid_rescale",
   "list",
   "loader",
   "log",
   "loop",
   "lowlight_color",
   "magnify",
   "map",
   "mattecolor",
   "median",
   "mean_shift",
   "metric",
   "mode",
   "modulate",
   "moments",
   "monitor",
   "monochrome",
   "morph",
   "morphology",
   "mosaic",
   "motion_blur",
   "name",
   "negate",
   "noise",
   "normalize",
   "opaque",
   "ordered_dither",
   "orient",
   "page",
   "paint",
   "pause",
   "perceptible",
   "ping",
   "pointsize",
   "polaroid",
   "poly",
   "posterize",
   "precision",
   "preview",
   "process",
   "quality",
   "quantize",
   "quiet",
   "radial_blur",
   "raise",
   "random_threshold",
   "range_threshold",
   "red_primary",
   "regard_warnings",
   "region",
   "remote",
   "render",
   "repage",
   "resample",
   "resize",
   "resize_to_fill",
   "resize_to_fit",
   "resize_to_limit",
   "resize_and_pad",
   "respect_parentheses",
   "reverse",
   "roll",
   "rotate",
   "sample",
   "sampling_factor",
   "saver",
   "scale",
   "scene",
   "screen",
   "seed",
   "segment",
   "selective_blur",
   "separate",
   "sepia_tone",
   "shade",
   "shadow",
   "shared_memory",
   "sharpen",
   "shave",
   "shear",
   "sigmoidal_contrast",
   "silent",
   "similarity_threshold",
   "size",
   "sketch",
   "smush",
   "snaps",
   "solarize",
   "sort_pixels",
   "sparse_color",
   "splice",
   "spread",
   "statistic",
   "stegano",
   "stereo",
   "storage_type",
   "stretch",
   "strip",
   "stroke",
   "strokewidth",
   "style",
   "subimage_search",
   "swap",
   "swirl",
   "synchronize",
   "taint",
   "text_font",
   "threshold",
   "thumbnail",
   "tile_offset",
   "tint",
   "title",
   "transform",
   "transparent",
   "transparent_color",
   "transpose",
   "transverse",
   "treedepth",
   "trim",
   "type",
   "undercolor",
   "unique_colors",
   "units",
   "unsharp",
   "update",
   "valid_image",
   "view",
   "vignette",
   "virtual_pixel",
   "visual",
   "watermark",
   "wave",
   "wavelet_denoise",
   "weight",
   "white_balance",
   "white_point",
   "white_threshold",
   "window",
   "window_group",
  ].concat(ActiveStorage.supported_image_processing_methods)

  UNSUPPORTED_IMAGE_PROCESSING_ARGUMENTS = ActiveStorage.unsupported_image_processing_arguments

  class << self
    # Returns a Variation instance based on the given variator. If the variator is a Variation, it is
    # returned unmodified. If it is a String, it is passed to ActiveStorage::Variation.decode. Otherwise,
    # it is assumed to be a transformations Hash and is passed directly to the constructor.
    def wrap(variator)
      case variator
      when self
        variator
      when String
        decode variator
      else
        new variator
      end
    end

    # Returns a Variation instance with the transformations that were encoded by +encode+.
    def decode(key)
      new ActiveStorage.verifier.verify(key, purpose: :variation)
    end

    # Returns a signed key for the +transformations+, which can be used to refer to a specific
    # variation in a URL or combined key (like <tt>ActiveStorage::Variant#key</tt>).
    def encode(transformations)
      ActiveStorage.verifier.generate(transformations, purpose: :variation)
    end
  end

  def initialize(transformations)
    @transformations = transformations
  end

  # Accepts an open MiniMagick image instance, like what's returned by <tt>MiniMagick::Image.read(io)</tt>,
  # and performs the +transformations+ against it. The transformed image instance is then returned.
  def transform(image)
    ActiveSupport::Notifications.instrument("transform.active_storage") do
      transformations.each do |name, argument_or_subtransformations|
        validate_transformation(name, argument_or_subtransformations)
        image.mogrify do |command|
          if name.to_s == "combine_options"
            argument_or_subtransformations.each do |subtransformation_name, subtransformation_argument|
              validate_transformation(subtransformation_name, subtransformation_argument)
              pass_transform_argument(command, subtransformation_name, subtransformation_argument)
            end
          else
            validate_transformation(name, argument_or_subtransformations)
            pass_transform_argument(command, name, argument_or_subtransformations)
          end
        end
      end
    end
  end

  # Returns a signed key for all the +transformations+ that this variation was instantiated with.
  def key
    self.class.encode(transformations)
  end

  private
    def pass_transform_argument(command, method, argument)
      if eligible_argument?(argument)
        command.public_send(method, argument)
      else
        command.public_send(method)
      end
    end

    def eligible_argument?(argument)
      argument.present? && argument != true
    end

    def validate_transformation(name, argument)
      method_name = name.to_s.gsub("-","_")

      unless SUPPORTED_IMAGE_PROCESSING_METHODS.any? { |method| method_name == method }
        raise UnsupportedImageProcessingMethod, <<~ERROR.squish
          One or more of the provided transformation methods is not supported.
        ERROR
      end

      if argument.present?
        if argument.is_a?(String) || argument.is_a?(Symbol)
          validate_arg_string(argument)
        elsif argument.is_a?(Array)
          validate_arg_array(argument)
        elsif argument.is_a?(Hash)
          validate_arg_hash(argument)
        end
      end
    end

    def validate_arg_string(argument)
      if UNSUPPORTED_IMAGE_PROCESSING_ARGUMENTS.any? { |bad_arg| argument.to_s.downcase.include?(bad_arg) }; raise UnsupportedImageProcessingArgument end
    end

    def validate_arg_array(argument)
      argument.each do |arg|
        if arg.is_a?(Integer) || arg.is_a?(Float)
          next
        elsif arg.is_a?(String) || arg.is_a?(Symbol)
          validate_arg_string(arg)
        elsif arg.is_a?(Array)
          validate_arg_array(arg)
        elsif arg.is_a?(Hash)
          validate_arg_hash(arg)
        end
      end
    end

    def validate_arg_hash(argument)
      argument.each do |key, value|
        validate_arg_string(key)

        if value.is_a?(Integer) || value.is_a?(Float)
          next
        elsif value.is_a?(String) || value.is_a?(Symbol)
          validate_arg_string(value)
        elsif value.is_a?(Array)
          validate_arg_array(value)
        elsif value.is_a?(Hash)
          validate_arg_hash(value)
        end
      end
    end
end
