# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::Blob::AnalyzableTest < ActiveSupport::TestCase
  class AnalyzerA < ActiveStorage::Analyzer
    def self.accept?(blob)
      true
    end

    def metadata
      { analyzed_by: { a: true } }
    end
  end

  class AnalyzerB < ActiveStorage::Analyzer
    def self.accept?(blob)
      true
    end

    def metadata
      { analyzed_by: { b: true } }
    end
  end

  class AnalyzerC < ActiveStorage::Analyzer
    def self.accept?(blob)
      false
    end

    def metadata
      { analyzed_by: { c: true } }
    end
  end

  test "#analyze supports multiple analyzers for a Blob" do
    ActiveStorage.with analyzers: [AnalyzerA, AnalyzerB, AnalyzerC] do
      blob = create_blob(filename: "racecar.jpeg")

      analyzed_by = extract_metadata_from(blob).fetch(:analyzed_by)

      assert_equal true, analyzed_by[:a]
      assert_equal true, analyzed_by[:b]
      assert_equal false, analyzed_by.key?(:c)
    end
  end
end
