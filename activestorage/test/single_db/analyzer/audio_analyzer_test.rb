# frozen_string_literal: true

require "single_db_test_helper"
require "minitest/mock"

mock_generators = Struct.new(:options, :orm).new(options: {custom_active_record: {}}, orm: :custom_active_record)
mock_config = Struct.new(:generators).new(generators: mock_generators)

Rails.stub :configuration, mock_config do
  require "database/setup"
end

require "active_storage/analyzer/audio_analyzer"

class ActiveStorage::Analyzer::AudioAnalyzerTest < ActiveSupport::TestCase
  test "analyzing an audio" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")
    metadata = extract_metadata_from(blob)

    assert_equal 0.914286, metadata[:duration]
    assert_equal 128000, metadata[:bit_rate]
    assert_equal 44100, metadata[:sample_rate]
    assert_not_nil metadata[:tags]
    assert_equal "Lavc57.64", metadata[:tags][:encoder]
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
