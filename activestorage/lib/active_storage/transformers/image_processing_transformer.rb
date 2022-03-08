# frozen_string_literal: true

begin
  require "image_processing"
rescue LoadError
  raise LoadError, <<~ERROR.squish
    Generating image variants require the image_processing gem.
    Please add `gem 'image_processing', '~> 1.2'` to your Gemfile.
  ERROR
end

module ActiveStorage
  module Transformers
    class ImageProcessingTransformer < Transformer
      private
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
          "window_group"
        ].concat(ActiveStorage.supported_image_processing_methods)

        UNSUPPORTED_IMAGE_PROCESSING_ARGUMENTS = ActiveStorage.unsupported_image_processing_arguments

        def process(file, format:)
          processor.
            source(file).
            loader(page: 0).
            convert(format).
            apply(operations).
            call
        end

        def processor
          ImageProcessing.const_get(ActiveStorage.variant_processor.to_s.camelize)
        end

        def operations
          transformations.each_with_object([]) do |(name, argument), list|
            if ActiveStorage.variant_processor == :mini_magick
              validate_transformation(name, argument)
            end

            if name.to_s == "combine_options"
              raise ArgumentError, <<~ERROR.squish
                Active Storage's ImageProcessing transformer doesn't support :combine_options,
                as it always generates a single ImageMagick command.
              ERROR
            end

            if argument.present?
              list << [ name, argument ]
            end
          end
        end

        def validate_transformation(name, argument)
          method_name = name.to_s.tr("-", "_")

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
  end
end
