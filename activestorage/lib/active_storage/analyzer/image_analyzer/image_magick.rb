# frozen_string_literal: true

begin
  gem "mini_magick"
  require "mini_magick"
rescue LoadError => error
  raise error unless error.message.include?("mini_magick")
end

module ActiveStorage
  # This analyzer relies on the third-party {MiniMagick}[https://github.com/minimagick/minimagick] gem. MiniMagick requires
  # the {ImageMagick}[http://www.imagemagick.org] system library.
  class Analyzer::ImageAnalyzer::ImageMagick < Analyzer::ImageAnalyzer
    private
      def read_image
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
