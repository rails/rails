# frozen_string_literal: true

require "abstract_unit"
require "rails/code_statistics"

class CodeStatisticsReportTest < ActiveSupport::TestCase
  def setup
    @tmp_path = File.expand_path("fixtures/tmp", __dir__)
    FileUtils.mkdir_p(@tmp_path)
    File.write File.join(@tmp_path, "example.rb"), <<-CODE
      def foo
        puts 'foo'
      end
    CODE
    @code_statistics = CodeStatistics.new(["tmp dir", @tmp_path])
  end

  def teardown
    FileUtils.rm_rf(@tmp_path)
  end

  test "build text report using #to_s" do
    report = @code_statistics.to_s
    result = <<~TEXT
    +----------------------+--------+--------+---------+---------+-----+-------+
    | Name                 |  Lines |    LOC | Classes | Methods | M/C | LOC/M |
    +----------------------+--------+--------+---------+---------+-----+-------+
    | tmp dir              |      3 |      3 |       0 |       1 |   0 |     1 |
    +----------------------+--------+--------+---------+---------+-----+-------+
      Code LOC: 3     Test LOC: 0     Code to Test Ratio: 1:0.0
    TEXT

    assert_equal report, result
  end

  test "build html report using #to_html" do
    report = @code_statistics.to_html
    assert_includes report, %(<td class="name">tmp dir</td>)
    assert_includes report, %(<li>Code LOC: 3</li>)
  end

  test "build html report using #to_json" do
    report = @code_statistics.to_json
    result = JSON.parse(report)
    assert_equal result["data"][0]["Name"], "tmp dir"
    assert_equal result["data"][0]["Lines"], 3
    assert_equal result["test stats"]["Code LOC"], 3
  end
end
