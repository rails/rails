# frozen_string_literal: true

require "image_processing/mini_magick"

module ActiveStorage
  module Transformers
    class ImageMagick < ImageProcessingTransformer
      private
        def processor
          ImageProcessing::MiniMagick
        end

        def supported_methods
          ActiveStorage.supported_image_processing_methods
        end
    end
  end
end
