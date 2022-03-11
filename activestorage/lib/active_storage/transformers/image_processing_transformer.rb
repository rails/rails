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

        def processor
          ImageProcessing.const_get(ActiveStorage.variant_processor.to_s.camelize)
        end

        def operations
          transformations.each_with_object([]) do |(name, argument), list|
            if ActiveStorage.variant_processor == :mini_magick
              validate_transformation(name, argument)
            end

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

        def validate_transformation(name, argument)
          method_name = name.to_s.tr("-", "_")

          unless ActiveStorage.supported_image_processing_methods.any? { |method| method_name == method }
            raise UnsupportedImageProcessingMethod, <<~ERROR.squish
              One or more of the provided transformation methods is not supported.
            ERROR
          end

          if argument.present?
            if argument.is_a?(String) || argument.is_a?(Symbol)
              validate_arg_string(argument)
            elsif argument.is_a?(Array)
              validate_arg_array(argument)
            elsif argument.is_a?(Hash)
              validate_arg_hash(argument)
            end
          end
        end

        def validate_arg_string(argument)
          unsupported_arguments = ActiveStorage.unsupported_image_processing_arguments.any? do |bad_arg|
            argument.to_s.downcase.include?(bad_arg)
          end

          raise UnsupportedImageProcessingArgument if unsupported_arguments
        end

        def validate_arg_array(argument)
          argument.each do |arg|
            if arg.is_a?(Integer) || arg.is_a?(Float)
              next
            elsif arg.is_a?(String) || arg.is_a?(Symbol)
              validate_arg_string(arg)
            elsif arg.is_a?(Array)
              validate_arg_array(arg)
            elsif arg.is_a?(Hash)
              validate_arg_hash(arg)
            end
          end
        end

        def validate_arg_hash(argument)
          argument.each do |key, value|
            validate_arg_string(key)

            if value.is_a?(Integer) || value.is_a?(Float)
              next
            elsif value.is_a?(String) || value.is_a?(Symbol)
              validate_arg_string(value)
            elsif value.is_a?(Array)
              validate_arg_array(value)
            elsif value.is_a?(Hash)
              validate_arg_hash(value)
            end
          end
        end
    end
  end
end
