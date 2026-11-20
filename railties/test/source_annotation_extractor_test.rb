# frozen_string_literal: true

require "abstract_unit"
require "rails/source_annotation_extractor"

class SourceAnnotationExtractorTest < ActiveSupport::TestCase
  test "annotations extracted with a pattern are UTF-8 and invalid bytes are replaced" do
    Dir.mktmpdir do |dir|
      File.binwrite("#{dir}/index.html.erb", "<%# TODO: améliorer \xFF ici %>\n".b)
      annotation = Rails::SourceAnnotationExtractor.new("TODO").find_in(dir)["#{dir}/index.html.erb"].first

      assert_equal Encoding::UTF_8, annotation.text.encoding
      assert_equal "améliorer � ici", annotation.text
    end
  end
end
