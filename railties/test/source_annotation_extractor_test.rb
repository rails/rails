# frozen_string_literal: true

require "abstract_unit"
require "rails/source_annotation_extractor"

class SourceAnnotationExtractorTest < ActiveSupport::TestCase
  def setup
    @dir = File.expand_path("fixtures/tmp", __dir__)
    FileUtils.mkdir_p(@dir)
    File.write(File.join(@dir, "some_file.rb"), "# TODO: note in some file")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  test "enumerate does not modify the given options" do
    options = { dirs: [@dir], tag: true }

    capture(:stdout) { Rails::SourceAnnotationExtractor.enumerate("TODO", options) }

    assert_equal({ dirs: [@dir], tag: true }, options)
  end

  test "display does not modify the given options" do
    extractor = Rails::SourceAnnotationExtractor.new("TODO")
    results = extractor.find([@dir])
    options = { tag: true }

    capture(:stdout) { extractor.display(results, options) }

    assert_equal({ tag: true }, options)
  end
end
