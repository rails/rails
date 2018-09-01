# frozen_string_literal: true

require "mini_magick"

module ActiveStorage
  module Transformers
    class MiniMagickTransformer < Transformer
      private
        def process(file, format:)
          image = MiniMagick::Image.new(file.path, file)

          transformations.each do |name, argument_or_subtransformations|
            image.mogrify do |command|
              if name.to_s == "combine_options"
                argument_or_subtransformations.each do |subtransformation_name, subtransformation_argument|
                  pass_transform_argument(command, subtransformation_name, subtransformation_argument)
                end
              else
                pass_transform_argument(command, name, argument_or_subtransformations)
              end
            end
          end

          image.format(format) if format

          image.tempfile.tap(&:open)
        end

        def pass_transform_argument(command, method, argument)
          if argument == true
            command.public_send(method)
          elsif argument.present?
            command.public_send(method, argument)
          end
        end
    end
  end
end
