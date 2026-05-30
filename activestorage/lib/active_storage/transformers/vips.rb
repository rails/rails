# frozen_string_literal: true

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
