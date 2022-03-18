# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/analyzer/audio_analyzer"

class ActiveStorage::Analyzer::AudioAnalyzerTest < ActiveSupport::TestCase
  test "analyzing an audio" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")
    metadata = extract_metadata_from(blob)

    assert_equal 0.914286, metadata[:duration]
    assert_equal 128000, metadata[:bit_rate]
  end

  test "instrumenting analysis" do
    events = subscribe_events_from("analyze.active_storage")

    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")
    blob.analyze

    assert_equal 1, events.size
    assert_equal({ analyzer: "ffprobe" }, events.first.payload)
  end
end
