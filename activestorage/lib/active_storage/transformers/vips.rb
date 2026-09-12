# frozen_string_literal: true

# Do not remove or reorder these requires.
#
# active_storage/vips disables libvips's unfuzzed loaders and savers.
#
# Loading image_processing first preserves its actionable missing-gem warning before checking
# whether ruby-vips could load its native libraries. Skipping image_processing/vips when it
# could not matters: that file would require vips again and raise ImageProcessing::Error, which
# is not a LoadError and so would abort boot instead of being reported as a warning.
require "active_storage/vips"
require "image_processing"
raise LoadError, "libvips is not available" unless ActiveStorage::VIPS_AVAILABLE
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
