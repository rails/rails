# frozen_string_literal: true

require "image_processing/mini_magick"

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
