# frozen_string_literal: true

module ActiveStorage
  # = Active Storage Image \Analyzer
  #
  # This is an abstract base class for image analyzers, which extract width and height from an image blob. When
  # +ActiveStorage.generate_image_placeholders+ is enabled, they also extract an inline placeholder.
  #
  # If the image contains EXIF data indicating its angle is 90 or 270 degrees, its width and height are swapped for convenience.
  #
  # Example:
  #
  #   ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick.new(blob).metadata
  #   # => { width: 4104, height: 2736 }
  class Analyzer::ImageAnalyzer < Analyzer
    extend ActiveSupport::Autoload

    autoload :Vips
    autoload :ImageMagick

    def self.accept?(blob)
      blob.image?
    end

    def metadata
      read_image do |image|
        dimensions = if rotated_image?(image)
          { width: image.height, height: image.width }
        else
          { width: image.width, height: image.height }
        end

        dimensions.merge(placeholder_metadata(image))
      end
    end

    private
      def placeholder_metadata(image)
        if ActiveStorage.generate_image_placeholders && (placeholder = image_placeholder(image))
          { placeholder: placeholder }
        else
          {}
        end
      end

      def image_placeholder(_image)
      end
  end
end
