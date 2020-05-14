# frozen_string_literal: true

module ActiveStorage
  module Transformers
    # = Active Storage \Transformers \Transformer
    #
    # A Transformer applies a set of transformations to a file.
    #
    # The following concrete subclasses are included in Active Storage:
    #
    # * ActiveStorage::Transformers::ImageProcessingTransformer:
    #   backed by ImageProcessing, a common interface for MiniMagick and ruby-vips
    #
    # To choose the transformer for a blob, Active Storage calls +accept?+ on each registered
    # transformer in order. It uses the first transformer for which +accept?+ returns true when
    # given the blob. In a Rails application, add or remove transformers by manipulating
    # +Rails.application.config.active_storage.transformers+ in an initializer:
    #
    #   Rails.application.config.active_storage.transformers
    #   # => [ ActiveStorage::Transformer::ImageProcessingTransformer ]
    #
    #   # Add a custom transformer for audios and videos:
    #   Rails.application.config.active_storage.transformers << FfmpegTransformer
    #   # => [ ActiveStorage::Transformer::ImageProcessingTransformer, FfmpegTransformer ]
    #
    # Outside of a Rails application, modify +ActiveStorage.transformers+ instead.
    class Transformer
      attr_reader :transformations

      # Implement this method in a concrete subclass. Have it return true when given a blob from which
      # the transformer can generate a variant.
      def self.accept?(blob)
        false
      end

      def initialize(transformations)
        @transformations = transformations
      end

      # Applies the transformations to the source +file+, producing a target in the
      # specified +format+. Yields an open Tempfile containing the target. Closes and unlinks
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
        def create_tempfile(ext: "")
          ext = ".#{ext}" unless ext.blank? || ext.start_with?(".")
          tempfile = Tempfile.new(["transformer_", ext], binmode: true)
          yield tempfile
        ensure
          tempfile&.close!
        end

        # Returns an open Tempfile containing a transformed file in the given +format+.
        # All subclasses implement this method.
        def process(file, format:) # :doc:
          raise NotImplementedError
        end
    end
  end
end
