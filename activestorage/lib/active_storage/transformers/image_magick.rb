# frozen_string_literal: true

module ActiveStorage
  module Transformers
    class ImageMagick < ImageProcessingTransformer
      private
        def processor
          ImageProcessing::MiniMagick
        end
    end
  end
end
