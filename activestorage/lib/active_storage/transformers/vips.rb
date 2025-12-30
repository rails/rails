# frozen_string_literal: true

module ActiveStorage
  module Transformers
    class Vips < ImageProcessingTransformer
      def processor
        ImageProcessing::Vips
      end
    end
  end
end
