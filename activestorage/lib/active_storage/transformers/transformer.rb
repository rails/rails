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
    # An application can supply a transformer of its own in either of two ways. Both take a class
    # implementing the interface defined by Transformer.
    #
    # Setting +config.active_storage.variant_processor+ replaces the transformer used for every
    # variant:
    #
    #   config.active_storage.variant_processor = CustomTransformer
    #
    # Adding to +config.active_storage.transformers+ instead registers a transformer alongside the
    # variant processor, which goes on handling everything the registered ones do not claim. Each
    # is asked whether it accepts a blob, the way previewers already are, and a blob accepted by
    # one is variable even when its media type is not an image:
    #
    #   config.active_storage.transformers = [ AudioTransformer ]
    class Transformer
      attr_reader :transformations

      # Implement this method in a transformer registered in
      # +config.active_storage.transformers+. Have it return true when given a blob the transformer
      # can transform. The variant processor is never asked, so a transformer installed only
      # through +config.active_storage.variant_processor+ does not need to implement it.
      def self.accept?(blob)
        false
      end

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
