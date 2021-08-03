# frozen_string_literal: true

begin
  require "image_processing"
rescue LoadError
  raise LoadError, <<~ERROR.squish
    Generating image variants require the image_processing gem.
    Please add `gem 'image_processing', '~> 1.2'` to your Gemfile.
  ERROR
end

module ActiveStorage
  module Transformers
    class ImageProcessingTransformer < Transformer
      private
        def process(file, format:)
          processor.
            source(file).
            loader(page: 0).
            convert(format).
            apply(operations).
            call
        end

        def processor
          ImageProcessing.const_get(ActiveStorage.variant_processor.to_s.camelize)
        end

        def operations
          transformations.each_with_object([]) do |(name, argument), list|
            if name.to_s == "combine_options"
              raise ArgumentError, <<~ERROR.squish
                Active Storage's ImageProcessing transformer doesn't support :combine_options,
                as it always generates a single command.
              ERROR
            end

            if argument.present?
              list << [ name, argument ]
            end
          end
        end
    end
  end
end
