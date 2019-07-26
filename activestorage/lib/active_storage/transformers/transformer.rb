# frozen_string_literal: true

module ActiveStorage
  module Transformers
    # A Transformer applies a set of transformations to an image.
    #
    # The following concrete subclasses are included in Active Storage:
    #
    # * ActiveStorage::Transformers::ImageProcessingTransformer:
    #   backed by ImageProcessing, a common interface for MiniMagick and ruby-vips
    #
    # * ActiveStorage::Transformers::MiniMagickTransformer:
    #   backed by MiniMagick, a wrapper around the ImageMagick CLI
    class Transformer
      attr_reader :transformations

      def initialize(transformations)
        @transformations = transformations
      end

      # Applies the transformations to the source image in +file+, producing a target image in the
      # specified +format+. Yields an open Tempfile containing the target image. Closes and unlinks
      # the output tempfile after yielding to the given block. Returns the result of the block.
      def transform(file, format:)
        output = process(file, format: format)

        begin
          yield output
        ensure
          output.close!
        end
      end

      private
        # Returns an open Tempfile containing a transformed image in the given +format+.
        # All subclasses implement this method.
        def process(file, format:) #:doc:
          raise NotImplementedError
        end
    end
  end
end
