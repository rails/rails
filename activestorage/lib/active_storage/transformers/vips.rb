# frozen_string_literal: true

# Do not remove either of these requires.
#
# active_storage/vips disables libvips's unfuzzed loaders and savers.
#
# active_storage/vips has already loaded image_processing/vips, but requiring it here is what
# raises LoadError when the gem is missing, which the engine reports as an actionable warning.
require "active_storage/vips"
require "image_processing/vips"

module ActiveStorage
  module Transformers
    class Vips < ImageProcessingTransformer
      def processor
        ImageProcessing::Vips
      end
    end
  end
end
