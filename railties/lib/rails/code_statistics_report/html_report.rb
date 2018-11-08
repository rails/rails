# frozen_string_literal: true

require "rails/code_statistics_report/base"

module CodeStatisticsReport #:nodoc:
  class HtmlReport < Base #:nodoc:
    def result
      stats_table + code_test_stats
    end

    private
      def stats_table
        (+%(<table border="1" cellspacing="0">)).tap do |table|
          table << %(<tr>)
          %w[Name Lines LOC Classes Methods M/C LOC/M].each do |name|
            table << %(<th>#{name}</th>)
          end
          table << %(</tr>)

          pairs.each do |pair|
            table << build_row(pair.first, statistics[pair.first])
          end

          if total
            table << build_row("Total", total)
          end

          table << "</table>"
        end
      end

      def code_test_stats
        (+%(<ul>)).tap do |ul|
          ul << "<li>Code LOC: #{code}</li>"
          ul << "<li>Test LOC: #{tests}</li>"
          ul << "<li>Code to Test Ratio: 1:#{code_to_test_ratio}</li>"
          ul << "</ul>"
        end
      end

      def build_row(name, statistics)
        m_over_c   = (statistics.methods / statistics.classes) rescue m_over_c = 0
        loc_over_m = (statistics.code_lines / statistics.methods) - 2 rescue loc_over_m = 0

        (+%(<tr>)).tap do |row|
          row << %(<tr>)
          row << %(<td class="name">#{name}</td>)
          %w[lines code_lines classes methods].each do |k|
            row << %(<td class="value">#{statistics.send(k)}</td>)
          end
          row << %(<td class="value">#{m_over_c}</td>)
          row << %(<td class="value">#{loc_over_m}</td>)
          row << %(</tr>)
        end
      end
  end
end
