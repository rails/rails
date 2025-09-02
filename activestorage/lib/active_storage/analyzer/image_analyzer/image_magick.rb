# frozen_string_literal: true

module ActiveStorage
  # This analyzer relies on the third-party {MiniMagick}[https://github.com/minimagick/minimagick] gem. MiniMagick requires
  # the {ImageMagick}[http://www.imagemagick.org] system library.
  class Analyzer::ImageAnalyzer::ImageMagick < Analyzer::ImageAnalyzer
    def self.accept?(blob)
      super && ActiveStorage.variant_processor == :mini_magick
    end

    private
      def read_image
        begin
          require "mini_magick"
        rescue LoadError
          logger.info "Skipping image analysis because the mini_magick gem isn't installed"
          return {}
        end

        download_blob_to_tempfile do |file|
          image = instrument("mini_magick") do
            MiniMagick::Image.new(file.path)
          end

          if image.valid?
            yield image
          else
            logger.info "Skipping image analysis because ImageMagick doesn't support the file"
            {}
          end
        rescue MiniMagick::Error => error
          logger.error "Skipping image analysis due to an ImageMagick error: #{error.message}"
          {}
        end
      end

      def rotated_image?(image)
        %w[ RightTop LeftBottom TopRight BottomLeft ].include?(image["%[orientation]"])
      end
  end
end
