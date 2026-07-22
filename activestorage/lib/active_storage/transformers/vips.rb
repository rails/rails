# frozen_string_literal: true

module ActiveStorage
  module Transformers
    class Vips < ImageProcessingTransformer
      def processor
        ImageProcessing::Vips
      end

      private
        def supported_image_processing_methods
          ActiveStorage.supported_vips_image_processing_methods
        end
    end
  end
end
