# frozen_string_literal: true

require "test_helper"
require "active_storage/analyzer/image_analyzer"

class ActiveStorage::Analyzer::ImageAnalyzerTest < ActiveSupport::TestCase
  class CustomAnalyzer < ActiveStorage::Analyzer::ImageAnalyzer
    private
      def read_image
        yield Struct.new(:width, :height).new(640, 480)
      end

      def rotated_image?(image)
        false
      end
  end

  test "custom analyzers do not need to implement image placeholders" do
    ActiveStorage.with(generate_image_placeholders: true) do
      assert_equal({ width: 640, height: 480 }, CustomAnalyzer.new(nil).metadata)
    end
  end
end
