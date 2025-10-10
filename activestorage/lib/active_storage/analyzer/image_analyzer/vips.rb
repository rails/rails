# frozen_string_literal: true

begin
  require "nokogiri"
rescue LoadError
  # Ensure nokogiri is loaded before vips, which also depends on libxml2.
  # See Nokogiri RFC: Stop exporting symbols:
  #   https://github.com/sparklemotion/nokogiri/discussions/2746
end

begin
  gem "ruby-vips"
  require "ruby-vips"
  ActiveStorage::VIPS_AVAILABLE = true # :nodoc:
rescue LoadError => error
  ActiveStorage::VIPS_AVAILABLE = false # :nodoc:
  raise error unless error.message.match?(/libvips|ruby-vips/)
end

module ActiveStorage
  # This analyzer relies on the third-party {ruby-vips}[https://github.com/libvips/ruby-vips] gem. Ruby-vips requires
  # the {libvips}[https://libvips.github.io/libvips/] system library.
  class Analyzer::ImageAnalyzer::Vips < Analyzer::ImageAnalyzer
    def self.accept?(blob)
      super && ActiveStorage.variant_processor == :vips
    end

    private
      def read_image
        unless VIPS_AVAILABLE
          logger.error "Skipping image analysis because the ruby-vips gem isn't installed"
          return {}
        end

        download_blob_to_tempfile do |file|
          image = instrument("vips") do
            # ruby-vips will raise Vips::Error if it can't find an appropriate loader for the file
            ::Vips::Image.new_from_file(file.path, access: :sequential)
          rescue ::Vips::Error
            logger.info "Skipping image analysis because Vips doesn't support the file"
            nil
          end

          if image
            yield image
          else
            {}
          end
        rescue ::Vips::Error => error
          logger.error "Skipping image analysis due to a Vips error: #{error.message}"
          {}
        end
      rescue ::Vips::Error => error
        logger.error "Skipping image analysis due to an Vips error: #{error.message}"
        {}
      end

      ROTATIONS = /Right-top|Left-bottom|Top-right|Bottom-left/
      def rotated_image?(image)
        ROTATIONS === image.get("exif-ifd0-Orientation")
      rescue ::Vips::Error
        false
      end
  end
end
