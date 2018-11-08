# frozen_string_literal: true

require "rails/code_statistics_report/base"

module CodeStatisticsReport #:nodoc:
  class TextReport < Base #:nodoc:
    HEADERS = { lines: " Lines", code_lines: "   LOC", classes: "Classes", methods: "Methods" }

    def result
      header.tap do |str|
        pairs.each do |pair|
          str << build_line(pair.first, statistics[pair.first])
        end
        str << splitter

        if total
          str << build_line("Total", total)
          str << splitter
        end

        str << code_test_stats
      end
    end

    private
      def header
        splitter.tap do |str|
          str << "| Name                "
          HEADERS.each do |k, v|
            str << " | #{v.rjust(width_for(k))}"
          end
          str << " | M/C | LOC/M |\n"
          str << splitter
        end
      end

      def splitter
        (+"+----------------------").tap do |str|
          HEADERS.each_key do |k|
            str << "+#{'-' * (width_for(k) + 2)}"
          end
          str << "+-----+-------+\n"
        end
      end

      def build_line(name, statistics)
        m_over_c   = (statistics.methods / statistics.classes) rescue m_over_c = 0
        loc_over_m = (statistics.code_lines / statistics.methods) - 2 rescue loc_over_m = 0

        (+"| #{name.ljust(20)} ").tap do |str|
          HEADERS.each_key do |k|
            str << "| #{statistics.send(k).to_s.rjust(width_for(k))} "
          end
          str << "| #{m_over_c.to_s.rjust(3)} | #{loc_over_m.to_s.rjust(5)} |\n"
        end
      end

      def code_test_stats
        "  Code LOC: #{code}     Test LOC: #{tests}     Code to Test Ratio: 1:#{code_to_test_ratio}\n"
      end

      def width_for(label)
        [statistics.values.sum { |s| s.send(label) }.to_s.size, HEADERS[label].length].max
      end
  end
end
