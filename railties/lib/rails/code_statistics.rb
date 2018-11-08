# frozen_string_literal: true

require "rails/code_statistics_calculator"
require "rails/code_statistics_report/html_report"
require "rails/code_statistics_report/json_report"
require "rails/code_statistics_report/text_report"
require "active_support/core_ext/enumerable"
require "active_support/deprecation"

class CodeStatistics #:nodoc:
  class TestTypes
    attr_reader :value

    def initialize
      @value = []
    end

    def <<(type)
      ActiveSupport::Deprecation.warn("`CodeStatistics::TEST_TYPES` constants is deprecated and will be removed in Rails 6.1. Use `Rails.application.config.code_statistics.test_types` instead.\n")
      @value << type
    end
  end

  TEST_TYPES = TestTypes.new

  attr_reader :pairs, :statistics, :total, :code, :tests, :code_to_test_ratio

  def initialize(*pairs)
    @pairs      = pairs
    @statistics = calculate_statistics
    @total      = calculate_total if pairs.length > 1
    @code       = calculate_code
    @tests      = calculate_tests
    @code_to_test_ratio = sprintf("%.1f", tests.to_f / code)
  end

  def to_s
    CodeStatisticsReport::TextReport.new(self).result
  end

  def to_html
    CodeStatisticsReport::HtmlReport.new(self).result
  end

  def to_json
    CodeStatisticsReport::JsonReport.new(self).result
  end

  private
    def calculate_statistics
      Hash[pairs.map { |pair| [pair.first, calculate_directory_statistics(pair.last)] }]
    end

    def calculate_directory_statistics(directory, pattern = /^(?!\.).*?\.(rb|js|coffee|rake)$/)
      stats = CodeStatisticsCalculator.new

      Dir.foreach(directory) do |file_name|
        path = "#{directory}/#{file_name}"

        if File.directory?(path) && (/^\./ !~ file_name)
          stats.add(calculate_directory_statistics(path, pattern))
        elsif file_name&.match?(pattern)
          stats.add_by_file_path(path)
        end
      end

      stats
    end

    def calculate_total
      statistics.each_with_object(CodeStatisticsCalculator.new) do |pair, total|
        total.add(pair.last)
      end
    end

    def calculate_code
      code_loc = 0
      statistics.each { |k, v| code_loc += v.code_lines unless test_types.include? k }
      code_loc
    end

    def calculate_tests
      test_loc = 0
      statistics.each { |k, v| test_loc += v.code_lines if test_types.include? k }
      test_loc
    end

    def test_types
      @test_types ||= Rails.application.config.code_statistics.test_types + TEST_TYPES.value
    end
end
