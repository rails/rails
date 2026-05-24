# frozen_string_literal: true

#--
# Copyright (c) David Heinemeier Hansson, 37signals LLC
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

begin
  require "active_record"
rescue LoadError => error
  raise unless error.path == "active_record"
end

require "active_support"
require "active_support/rails"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/numeric/bytes"
require "concurrent/map"

require "active_storage/version"
require "active_storage/deprecator"
require "active_storage/errors"

require "marcel"
require "openssl"

# :markup: markdown
# :include: ../README.md
module ActiveStorage
  extend ActiveSupport::Autoload

  @@blob_class           = "ActiveStorage::Blob"
  @@attachment_class     = "ActiveStorage::Attachment"
  @@variant_record_class = "ActiveStorage::VariantRecord"

  # Metadata keys Active Storage owns internally and must not accept from direct-upload clients.
  PROTECTED_BLOB_METADATA = %w(analyzed identified composed).flat_map { |key| [key, key.to_sym] }.freeze
  private_constant :PROTECTED_BLOB_METADATA

  autoload :Attached
  autoload :FixtureSet
  autoload :Service
  autoload :Servable
  autoload :Services
  autoload :Previewer
  autoload :Analyzer
  autoload :Reflection

  mattr_accessor :logger
  mattr_accessor :verifier
  mattr_accessor :variant_processor, default: :mini_magick

  mattr_accessor :variant_transformer

  mattr_accessor :queues, default: {}

  mattr_accessor :previewers, default: []
  mattr_accessor :analyzers,  default: []
  mattr_accessor :analyze,    default: :later

  mattr_accessor :paths, default: {}

  mattr_accessor :variable_content_types,           default: []
  mattr_accessor :web_image_content_types,          default: []
  mattr_accessor :binary_content_type,              default: "application/octet-stream"
  mattr_accessor :content_types_to_serve_as_binary, default: []
  mattr_accessor :content_types_allowed_inline,     default: []

  mattr_accessor :supported_image_processing_methods, default: [
    "adaptive_blur",
    "adaptive_resize",
    "adaptive_sharpen",
    "adjoin",
    "affine",
    "alpha",
    "annotate",
    "antialias",
    "append",
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
  ]
  mattr_accessor :unsupported_image_processing_arguments

  mattr_accessor :streaming_chunk_max_size, default: 100.megabytes
  mattr_accessor :service_urls_expire_in, default: 5.minutes
  mattr_accessor :touch_attachment_records, default: true
  mattr_accessor :urls_expire_in

  class << self
    attr_accessor :class_configuration_loaded # :nodoc:

    def blob_class_name # :nodoc:
      @@blob_class
    end

    def attachment_class_name # :nodoc:
      @@attachment_class
    end

    def variant_record_class_name # :nodoc:
      @@variant_record_class
    end

    # Returns the configured class used to persist blobs. Defaults to ActiveStorage::Blob.
    def blob_class
      @blob_class_resolved ||= resolve_class(@@blob_class, :blob_class)
    end

    # Sets the blob persistence class and clears its cached constant.
    #
    # Accepts a named class or its constant name.
    def blob_class=(klass_or_name)
      @@blob_class = class_name(klass_or_name)
      @blob_class_resolved = nil
    end

    # Returns the configured class used to persist attachments. Defaults to ActiveStorage::Attachment.
    def attachment_class
      @attachment_class_resolved ||= resolve_class(@@attachment_class, :attachment_class)
    end

    # Sets the attachment persistence class and clears its cached constant.
    #
    # Accepts a named class or its constant name.
    def attachment_class=(klass_or_name)
      @@attachment_class = class_name(klass_or_name)
      @attachment_class_resolved = nil
    end

    # Returns the configured class used to persist variants. Defaults to ActiveStorage::VariantRecord.
    def variant_record_class
      @variant_record_class_resolved ||= resolve_class(@@variant_record_class, :variant_record_class)
    end

    # Sets the variant persistence class and clears its cached constant.
    #
    # Accepts a named class or its constant name.
    def variant_record_class=(klass_or_name)
      @@variant_record_class = class_name(klass_or_name)
      @variant_record_class_resolved = nil
    end

    def clear_class_indirection_cache # :nodoc:
      @blob_class_resolved = nil
      @attachment_class_resolved = nil
      @variant_record_class_resolved = nil
    end

    # Removes metadata keys that Active Storage owns internally.
    #
    # Non-hash values are returned unchanged for the backend to validate.
    def filter_blob_metadata(metadata)
      if metadata.is_a?(Hash)
        metadata.without(*PROTECTED_BLOB_METADATA)
      else
        metadata
      end
    end

    private
      def resolve_class(name, option)
        resolved = name.safe_constantize
        unless resolved
          raise ConfigurationError,
            "config.active_storage.#{option} = #{name.inspect} but that constant is not defined. " \
            "Ensure the third-party gem providing the class is required and its constant is loadable."
        end
        resolved
      end

      def class_name(klass_or_name)
        if klass_or_name.is_a?(String)
          raise ArgumentError, "Active Storage class names cannot be blank" if klass_or_name.empty?

          klass_or_name
        elsif klass_or_name.respond_to?(:name) && klass_or_name.name
          klass_or_name.name
        else
          raise ArgumentError, "Active Storage class configuration must be a class name or named class"
        end
      end
  end

  # Configures the mount point for the default Active Storage routes. Accepts any
  # value supported by `scope`, such as a string path prefix or a hash of routing
  # options.
  mattr_accessor :routes_prefix, default: "/rails/active_storage"
  mattr_accessor :draw_routes, default: true
  mattr_accessor :resolve_model_to_route, default: :rails_storage_redirect

  mattr_accessor :base_controller_parent, default: "::ActionController::Base"

  mattr_accessor :track_variants, default: false

  singleton_class.attr_accessor :checksum_implementation
  @checksum_implementation = OpenSSL::Digest::MD5
  begin
    @checksum_implementation.hexdigest("test")
  rescue # OpenSSL may have MD5 disabled
    require "digest/md5"
    @checksum_implementation = Digest::MD5
  end

  singleton_class.attr_accessor :streaming_max_ranges
  @streaming_max_ranges = 1

  mattr_accessor :video_preview_arguments, default: "-y -vframes 1 -f image2"

  mattr_accessor :video_preview_input_arguments, default: ""

  mattr_accessor :ffprobe_arguments, default: ""

  module Transformers
    extend ActiveSupport::Autoload

    autoload :Transformer
    autoload :NullTransformer
    autoload :ImageProcessingTransformer
    autoload :Vips
    autoload :ImageMagick
  end
end
