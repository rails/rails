# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

require "active_storage/analyzer/image_analyzer"

class ActiveStorage::Analyzer::ImageAnalyzer::VipsTest < ActiveSupport::TestCase
  test "analyzing a JPEG image" do
    analyze_with_vips do
      main_blob = create_main_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      main_metadata = extract_metadata_from(main_blob)

      animals_blob = create_animals_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      animals_metadata = extract_metadata_from(animals_blob)

      assert_equal 4104, main_metadata[:width]
      assert_equal 2736, main_metadata[:height]

      assert_equal 4104, animals_metadata[:width]
      assert_equal 2736, animals_metadata[:height]
    end
  end

  test "analyzing a rotated JPEG image" do
    analyze_with_vips do
      main_blob = create_main_file_blob(filename: "racecar_rotated.jpg", content_type: "image/jpeg")
      main_metadata = extract_metadata_from(main_blob)

      animals_blob = create_animals_file_blob(filename: "racecar_rotated.jpg", content_type: "image/jpeg")
      animals_metadata = extract_metadata_from(animals_blob)

      assert_equal 2736, main_metadata[:width]
      assert_equal 4104, main_metadata[:height]

      assert_equal 2736, animals_metadata[:width]
      assert_equal 4104, animals_metadata[:height]
    end
  end

  test "analyzing an SVG image without an XML declaration" do
    analyze_with_vips do
      main_blob = create_main_file_blob(filename: "icon.svg", content_type: "image/svg+xml")
      main_metadata = extract_metadata_from(main_blob)

      animals_blob = create_animals_file_blob(filename: "icon.svg", content_type: "image/svg+xml")
      animals_metadata = extract_metadata_from(animals_blob)

      assert_equal 792, main_metadata[:width]
      assert_equal 584, main_metadata[:height]

      assert_equal 792, animals_metadata[:width]
      assert_equal 584, animals_metadata[:height]
    end
  end

  test "analyzing an unsupported image type" do
    analyze_with_vips do
      main_blob = create_main_blob(data: "bad", filename: "bad_file.bad", content_type: "image/bad_type")
      main_metadata = extract_metadata_from(main_blob)

      animals_blob = create_animals_blob(data: "bad", filename: "bad_file.bad", content_type: "image/bad_type")
      animals_metadata = extract_metadata_from(animals_blob)

      assert_nil main_metadata[:width]
      assert_nil main_metadata[:height]

      assert_nil animals_metadata[:width]
      assert_nil animals_metadata[:height]
    end
  end

  test "instrumenting analysis" do
    analyze_with_vips do
      main_blob = create_main_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      animals_blob = create_animals_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")

      assert_notifications_count("analyze.active_storage", 2) do
        assert_notification("analyze.active_storage", analyzer: "vips") do
          main_blob.analyze
          animals_blob.analyze
        end
      end
    end
  end

  private
    def analyze_with_vips
      previous_analyzers, ActiveStorage.analyzers = ActiveStorage.analyzers, [ActiveStorage::Analyzer::ImageAnalyzer::Vips]

      yield
    rescue LoadError
      ENV["BUILDKITE"] ? raise : skip("Variant processor vips is not installed")
    ensure
      ActiveStorage.analyzers = previous_analyzers
    end
end
