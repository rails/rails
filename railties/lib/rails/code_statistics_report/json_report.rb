# frozen_string_literal: true

require "rails/code_statistics_report/base"

module CodeStatisticsReport #:nodoc:
  class JsonReport < Base #:nodoc:
    def result
      {
        "data" => data_stats,
        "total" => total_stats,
        "test stats" => code_test_stats
      }.to_json
    end

    private
      def data_stats
        pairs.map do |pair|
          build_data(pair.first, statistics[pair.first])
        end
      end

      def total_stats
        total ? build_data("Total", total) : {}
      end

      def code_test_stats
        {
          "Code LOC" => code,
          "Test LOC" => tests,
          "Test Ratio" => "1:#{code_to_test_ratio}"
        }
      end

      def build_data(name, statistics)
        m_over_c   = (statistics.methods / statistics.classes) rescue m_over_c = 0
        loc_over_m = (statistics.code_lines / statistics.methods) - 2 rescue loc_over_m = 0

        {
          "Name" => name,
          "Lines" => statistics.lines,
          "LOC" => statistics.code_lines,
          "Classes" => statistics.classes,
          "Methods" => statistics.methods,
          "M/C" => m_over_c,
          "LOC/M" => loc_over_m
        }
      end
  end
end
