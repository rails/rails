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

require "active_record"
require "active_support"
require "active_support/rails"
require "active_support/core_ext/numeric/time"

require "active_storage/version"
require "active_storage/deprecator"
require "active_storage/errors"

require "marcel"

# :markup: markdown
# :include: ../README.md
module ActiveStorage
  extend ActiveSupport::Autoload

  autoload :Attached
  autoload :FixtureSet
  autoload :Service
  autoload :Previewer
  autoload :Analyzer

  mattr_accessor :logger
  mattr_accessor :verifier
  mattr_accessor :variant_processor, default: :mini_magick

  mattr_accessor :variant_transformer

  mattr_accessor :queues, default: {}

  mattr_accessor :previewers, default: []
  mattr_accessor :analyzers,  default: []

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

  mattr_accessor :service_urls_expire_in, default: 5.minutes
  mattr_accessor :touch_attachment_records, default: true
  mattr_accessor :urls_expire_in

  mattr_accessor :routes_prefix, default: "/rails/active_storage"
  mattr_accessor :draw_routes, default: true
  mattr_accessor :resolve_model_to_route, default: :rails_storage_redirect

  mattr_accessor :track_variants, default: false

  singleton_class.attr_accessor :checksum_implementation
  @checksum_implementation = OpenSSL::Digest::MD5
  begin
    @checksum_implementation.hexdigest("test")
  rescue # OpenSSL may have MD5 disabled
    require "digest/md5"
    @checksum_implementation = Digest::MD5
  end

  mattr_accessor :video_preview_arguments, default: "-y -vframes 1 -f image2"

  module Transformers
    extend ActiveSupport::Autoload

    autoload :Transformer
    autoload :NullTransformer
    autoload :ImageProcessingTransformer
    autoload :Vips
    autoload :ImageMagick
  end
end
