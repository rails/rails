# frozen_string_literal: true

module ActiveStorage
  # This analyzer relies on the third-party {ruby-vips}[https://github.com/libvips/ruby-vips] gem. Ruby-vips requires
  # the {libvips}[https://libvips.github.io/libvips/] system library.
  class Analyzer::ImageAnalyzer::Vips < Analyzer::ImageAnalyzer
    def self.accept?(blob)
      super && ActiveStorage.variant_processor == :vips
    end

    private
      def read_image
        begin
          require "ruby-vips"
        rescue LoadError
          logger.info "Skipping image analysis because the ruby-vips gem isn't installed"
          return {}
        end

        download_blob_to_tempfile do |file|
          image = instrument("vips") do
            ::Vips::Image.new_from_file(file.path, access: :sequential)
          end

          if valid_image?(image)
            yield image
          else
            logger.info "Skipping image analysis because Vips doesn't support the file"
            {}
          end
        rescue ::Vips::Error => error
          logger.error "Skipping image analysis due to an Vips error: #{error.message}"
          {}
        end
      end

      ROTATIONS = /Right-top|Left-bottom|Top-right|Bottom-left/
      def rotated_image?(image)
        ROTATIONS === image.get("exif-ifd0-Orientation")
      rescue ::Vips::Error
        false
      end

      def valid_image?(image)
        image.avg
        true
      rescue ::Vips::Error
        false
      end
  end
end
