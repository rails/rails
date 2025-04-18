# frozen_string_literal: true

require "test_helper"

require "active_storage/analyzer/audio_analyzer"

class ActiveStorage::Analyzer::AudioAnalyzerTest < ActiveSupport::TestCase
  test "analyzing an audio" do
    analyze_with("AudioAnalyzer") do
      blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")
      metadata = extract_metadata_from(blob)

      assert_equal 0.914286, metadata[:duration]
      assert_equal 128000, metadata[:bit_rate]
      assert_equal 44100, metadata[:sample_rate]
      assert_not_nil metadata[:tags]
      assert_equal "Lavc57.64", metadata[:tags][:encoder]
    end
  end

  test "instrumenting analysis" do
    analyze_with("AudioAnalyzer") do
      blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")

      assert_notifications_count("analyze.active_storage", 1) do
        assert_notification("analyze.active_storage", analyzer: "ffprobe") do
          blob.analyze
        end
      end
    end
  end
end
