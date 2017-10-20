# frozen_string_literal: true

require "abstract_unit"
require "rails/code_statistics"

class CodeStatisticsTest < ActiveSupport::TestCase
  def setup
    @tmp_path = File.expand_path("fixtures/tmp", __dir__)
    @dir_js   = File.join(@tmp_path, "lib.js")
    FileUtils.mkdir_p(@dir_js)
  end

  def teardown
    FileUtils.rm_rf(@tmp_path)
  end

  test "ignores directories that happen to have source files extensions" do
    assert_nothing_raised do
      @code_statistics = CodeStatistics.new(["tmp dir", @tmp_path])
    end
  end

  test "ignores hidden files" do
    File.write File.join(@tmp_path, ".example.rb"), <<-CODE
      def foo
        puts 'foo'
      end
    CODE

    assert_nothing_raised do
      CodeStatistics.new(["hidden file", @tmp_path])
    end
  end
end
