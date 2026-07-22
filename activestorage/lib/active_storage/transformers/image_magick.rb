# frozen_string_literal: true

module ActiveStorage
  module Transformers
    class ImageMagick < ImageProcessingTransformer
      private
        def processor
          ImageProcessing::MiniMagick
        end

        def supported_image_processing_methods
          ActiveStorage.supported_image_processing_methods
        end
    end
  end
end
