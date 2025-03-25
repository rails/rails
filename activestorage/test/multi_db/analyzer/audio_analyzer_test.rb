# frozen_string_literal: true

require "multi_db_test_helper"
require "minitest/mock"

mock_generators = Struct.new(:options, :orm).new(options: {custom_active_record: {}}, orm: :custom_active_record)
mock_config = Struct.new(:generators).new(generators: mock_generators)

Rails.stub :configuration, mock_config do
  require "database/setup"
end

require "active_storage/analyzer/audio_analyzer"

class ActiveStorage::Analyzer::AudioAnalyzerTest < ActiveSupport::TestCase
  test "analyzing an audio" do
    main_blob = create_main_file_blob(filename: "audio.mp3", content_type: "audio/mp3")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "audio.mp3", content_type: "audio/mp3")
    animals_metadata = extract_metadata_from(animals_blob)

    assert_equal 0.914286, main_metadata[:duration]
    assert_equal 128000, main_metadata[:bit_rate]
    assert_equal 44100, main_metadata[:sample_rate]
    assert_not_nil main_metadata[:tags]
    assert_equal "Lavc57.64", main_metadata[:tags][:encoder]

    assert_equal 0.914286, animals_metadata[:duration]
    assert_equal 128000, animals_metadata[:bit_rate]
    assert_equal 44100, animals_metadata[:sample_rate]
    assert_not_nil animals_metadata[:tags]
    assert_equal "Lavc57.64", animals_metadata[:tags][:encoder]
  end

  test "instrumenting analysis" do
    main_blob = create_main_file_blob(filename: "audio.mp3", content_type: "audio/mp3")
    animals_blob = create_animals_file_blob(filename: "audio.mp3", content_type: "audio/mp3")

    assert_notifications_count("analyze.active_storage", 2) do
      assert_notification("analyze.active_storage", analyzer: "ffprobe") do
        main_blob.analyze
        animals_blob.analyze
      end
    end
  end
end
