# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/analyzer/audio_analyzer"

class ActiveStorage::Analyzer::AudioAnalyzerTest < ActiveSupport::TestCase
  test "analyzing an audio" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")
    metadata = extract_metadata_from(blob)

    assert (0.863379..0.914286).include?(metadata[:duration])

    assert_equal 128000, metadata[:bit_rate]
    assert_equal 44100, metadata[:sample_rate]
    assert_not_nil metadata[:tags]
    assert_equal "Lavc57.64", metadata[:tags][:encoder]
  end

  test "analyzing a playlist declared as audio" do
    blob = create_playlist_blob(referencing: "audio.mp3", filename: "audio.m3u8", content_type: "audio/mpeg")
    metadata = extract_metadata_from(blob)

    assert_nil metadata[:duration]
    assert_nil metadata[:bit_rate]
  end

  test "analyzing an audio file whose format is not allowed" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")

    ActiveStorage.with(ffmpeg_allowed_formats: %w[ wav ], logger: ActiveSupport::Logger.new(log = StringIO.new)) do
      metadata = extract_metadata_from(blob)

      assert_nil metadata[:duration]
      assert_match "Audio analysis failed because ffprobe exited with status 1", log.string
    end
  end

  test "instrumenting analysis" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")

    assert_notifications_count("analyze.active_storage", 1) do
      assert_notification("analyze.active_storage", analyzer: "ffprobe") do
        blob.analyze
      end
    end
  end
end
