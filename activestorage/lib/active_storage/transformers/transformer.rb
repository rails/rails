# frozen_string_literal: true

module ActiveStorage
  module Transformers
    # = Active Storage \Transformers \Transformer
    #
    # A Transformer applies a set of transformations to an image.
    #
    # The following concrete subclasses are included in Active Storage:
    #
    # * ActiveStorage::Transformers::ImageProcessingTransformer:
    #   backed by ImageProcessing, a common interface for MiniMagick and ruby-vips
    #
    # An application can set +config.active_storage.variant_processor+ to a class. The class must
    # implement the interface defined by Transformer. Active Storage then uses it for variant
    # processing.
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
        def process(file, format:) # :doc:
          raise NotImplementedError
        end
    end
  end
end
