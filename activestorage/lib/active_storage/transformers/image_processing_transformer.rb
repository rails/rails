# frozen_string_literal: true

begin
  require "image_processing"
rescue LoadError
  raise LoadError, <<~ERROR.squish
    Generating image variants require the image_processing gem.
    Please add `gem "image_processing", "~> 1.2"` to your Gemfile.
  ERROR
end

module ActiveStorage
  module Transformers
    class ImageProcessingTransformer < Transformer
      private
        class UnsupportedImageProcessingMethod < StandardError; end
        class UnsupportedImageProcessingArgument < StandardError; end

        def process(file, format:)
          processor.
            source(file).
            loader(page: 0).
            convert(format).
            apply(operations).
            call
        end

        def operations
          transformations.each_with_object([]) do |(name, argument), list|
            validate_transformation(name, argument)

            if argument.present?
              list << [ name, argument ]
            end
          end
        end

        def validate_transformation(name, argument)
          if name.to_s == "combine_options"
            raise ArgumentError, <<~ERROR.squish
              Active Storage's ImageProcessing transformer doesn't support :combine_options,
              as it always generates a single command.
            ERROR
          end
        end
    end
  end
end
