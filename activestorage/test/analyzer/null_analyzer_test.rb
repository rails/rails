# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/analyzer/null_analyzer"

class ActiveStorage::Analyzer::NullAnalyzerTest < ActiveSupport::TestCase
  test "accepts any blob" do
    blob = create_blob

    assert ActiveStorage::Analyzer::NullAnalyzer.accept?(blob)
  end

  test "accepts image blobs" do
    blob = create_file_blob

    assert ActiveStorage::Analyzer::NullAnalyzer.accept?(blob)
  end

  test "does not analyze later" do
    assert_equal false, ActiveStorage::Analyzer::NullAnalyzer.analyze_later?
  end

  test "returns empty metadata" do
    blob = create_blob
    analyzer = ActiveStorage::Analyzer::NullAnalyzer.new(blob)

    assert_equal({}, analyzer.metadata)
  end
end
