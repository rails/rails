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

  test "output results in table format" do
    File.write File.join(@tmp_path, "example.rb"), <<-CODE
      class Example
        def foo
          puts 'foo'
        end
      end
    CODE

    code_statistics = CodeStatistics.new(["tmp dir", @tmp_path])
    expected = <<~TABLE
      +----------------------+--------+--------+---------+---------+-----+-------+
      | Name                 |  Lines |    LOC | Classes | Methods | M/C | LOC/M |
      +----------------------+--------+--------+---------+---------+-----+-------+
      | tmp dir              |      5 |      5 |       1 |       1 |   1 |     3 |
      +----------------------+--------+--------+---------+---------+-----+-------+
        Code LOC: 5     Test LOC: 0     Code to Test Ratio: 1:0.0

    TABLE

    output, _ = capture_io do
      code_statistics.to_s
    end

    assert_equal expected, output
  end

  test "return results in hash format" do
    File.write File.join(@tmp_path, "example.rb"), <<-CODE
      class Example
        def foo
          puts 'foo'
        end
      end
    CODE

    code_statistics = CodeStatistics.new(["tmp dir", @tmp_path])
    expected = {
      code_statistics: [
        {
          name: "tmp dir",
          statistic: {
            lines: 5,
            code_lines: 5,
            classes: 1,
            methods: 1
          }
        }
      ],
      total: nil
    }

    assert_equal expected, code_statistics.to_h
  end
end
