# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/analyzer/image_analyzer"

class ActiveStorage::Analyzer::CustomAnalyzerTest < ActiveSupport::TestCase
  class GPSAnalyzer < ActiveStorage::Analyzer
    def self.accept?(blob)
      blob.image?
    end

    def metadata
      read_image do |image|
        {
          gps: {
            latitude: image.exif["GPSLatitude"],
            longitude: image.exif["GPSLongitude"]
          }
        }
      end
    rescue LoadError
      logger.info "Skipping image analysis because the mini_magick gem isn't installed"
      {}
    end

    private
      def read_image
        download_blob_to_tempfile do |file|
          require "mini_magick"
          yield MiniMagick::Image.new(file.path)
        end
      end
  end

  test "using custom analyzer" do
    with_analyzers([GPSAnalyzer]) do
      blob = create_file_blob(filename: "image_with_gps.jpg", content_type: "image/jpeg")
      metadata = extract_metadata_from(blob)

      assert_includes metadata, :gps
      assert_not_nil metadata[:gps][:latitude]
      assert_not_nil metadata[:gps][:longitude]
    end
  end

  test "using default and custom analyzers" do
    with_analyzers([GPSAnalyzer, *ActiveStorage.analyzers]) do
      blob = create_file_blob(filename: "image_with_gps.jpg", content_type: "image/jpeg")
      metadata = extract_metadata_from(blob)

      assert_includes metadata, :gps
      assert_not_nil metadata[:gps][:latitude]
      assert_not_nil metadata[:gps][:longitude]
      assert_not_nil metadata[:width]
      assert_not_nil metadata[:height]
    end
  end

  private
    def with_analyzers(new_analyzers)
      old_analyzers = ActiveStorage.analyzers
      ActiveStorage.analyzers = new_analyzers
      yield
    ensure
      ActiveStorage.analyzers = old_analyzers
    end
end
