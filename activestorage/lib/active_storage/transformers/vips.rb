# frozen_string_literal: true

# Do not remove or reorder these setup steps.
#
# active_storage/vips disables libvips's unfuzzed loaders and savers. Requiring image_processing
# on its own is what raises the LoadError the engine reports when that gem is missing.
#
# Do not require image_processing/vips when ruby-vips is unavailable: it requires ruby-vips a
# second time, and image_processing before 2.0.2 raises ImageProcessing::Error instead of
# LoadError, which aborts boot.
require "active_storage/vips"
ActiveStorage.require_securable_vips!
require "image_processing"

raise LoadError, "libvips or the ruby-vips gem is not available" unless ActiveStorage::VIPS_AVAILABLE

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
