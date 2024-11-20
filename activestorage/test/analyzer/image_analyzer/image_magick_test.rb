# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/analyzer/image_analyzer"

class ActiveStorage::Analyzer::ImageAnalyzer::ImageMagickTest < ActiveSupport::TestCase
  test "analyzing a JPEG image" do
    analyze_with_image_magick do
      blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      metadata = extract_metadata_from(blob)

      assert_equal 4104, metadata[:width]
      assert_equal 2736, metadata[:height]
    end
  end

  test "analyzing a rotated JPEG image" do
    analyze_with_image_magick do
      blob = create_file_blob(filename: "racecar_rotated.jpg", content_type: "image/jpeg")
      metadata = extract_metadata_from(blob)

      assert_equal 2736, metadata[:width]
      assert_equal 4104, metadata[:height]
    end
  end

  test "analyzing an SVG image without an XML declaration" do
    analyze_with_image_magick do
      blob = create_file_blob(filename: "icon.svg", content_type: "image/svg+xml")
      metadata = extract_metadata_from(blob)

      assert_equal 792, metadata[:width]
      assert_equal 584, metadata[:height]
    end
  end

  test "analyzing an unsupported image type" do
    analyze_with_image_magick do
      blob = create_blob(data: "bad", filename: "bad_file.bad", content_type: "image/bad_type")
      metadata = extract_metadata_from(blob)

      assert_nil metadata[:width]
      assert_nil metadata[:height]
    end
  end

  test "instrumenting analysis" do
    analyze_with_image_magick do
      events = subscribe_events_from("analyze.active_storage")

      blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      blob.analyze

      assert_equal 1, events.size
      assert_equal({ analyzer: "mini_magick" }, events.first.payload)
    end
  end

  private
    def analyze_with_image_magick
      previous_processor, ActiveStorage.variant_processor = ActiveStorage.variant_processor, :mini_magick
      require "mini_magick"

      yield
    rescue LoadError
      ENV["BUILDKITE"] ? raise : skip("Variant processor image_magick is not installed")
    ensure
      ActiveStorage.variant_processor = previous_processor
    end
end
