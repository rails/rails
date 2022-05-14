# frozen_string_literal: true

module ActiveStorage
  module Transformers
    class ImageMagick < ImageProcessingTransformer
      private
        def processor
          ImageProcessing::MiniMagick
        end

        def validate_transformation(name, argument)
          method_name = name.to_s.tr("-", "_")

          unless ActiveStorage.supported_image_processing_methods.include?(method_name)
            raise UnsupportedImageProcessingMethod, <<~ERROR.squish
              The provided transformation method is not supported: #{method_name}.
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

          super
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
