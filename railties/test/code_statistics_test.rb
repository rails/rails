require "abstract_unit"
require "rails/code_statistics"
require "rails/code_statistics/registry"

class CodeStatisticsTest < ActiveSupport::TestCase
  def setup
    @tmp_path = File.expand_path("fixtures/tmp", __dir__)
    @dir_js   = File.join(@tmp_path, "lib.js")
    FileUtils.mkdir_p(@dir_js)
    @registry = CodeStatistics::Registry.new
  end

  def teardown
    FileUtils.rm_rf(@tmp_path)
  end

  test "ignores directories that happen to have source files extensions" do
    assert_nothing_raised do
      @registry.add("tmp dir", @tmp_path)
      @code_statistics = CodeStatistics.new(@registry)
    end
  end

  test "ignores hidden files" do
    File.write File.join(@tmp_path, ".example.rb"), <<-CODE
      def foo
        puts 'foo'
      end
    CODE

    assert_nothing_raised do
      CodeStatistics.new(@registry)
    end
  end
end
