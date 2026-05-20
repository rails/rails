# frozen_string_literal: true

require "image_processing/vips"

Vips.block_untrusted(false) if Vips.respond_to?(:block_untrusted) && !ENV["VIPS_BLOCK_UNTRUSTED"]

module ActiveStorage
  module Transformers
    class Vips < ImageProcessingTransformer
      def processor
        ImageProcessing::Vips
      end
    end
  end
end
