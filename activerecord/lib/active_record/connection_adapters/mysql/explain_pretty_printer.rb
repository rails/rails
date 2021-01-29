# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class ExplainPrettyPrinter # :nodoc:
        # Pretty prints the result of an EXPLAIN in a way that resembles the output of the
        # MySQL shell:
        #
        #   +----+-------------+-------+-------+---------------+---------+---------+-------+------+-------------+
        #   | id | select_type | table | type  | possible_keys | key     | key_len | ref   | rows | Extra       |
        #   +----+-------------+-------+-------+---------------+---------+---------+-------+------+-------------+
        #   |  1 | SIMPLE      | users | const | PRIMARY       | PRIMARY | 4       | const |    1 |             |
        #   |  1 | SIMPLE      | posts | ALL   | NULL          | NULL    | NULL    | NULL  |    1 | Using where |
        #   +----+-------------+-------+-------+---------------+---------+---------+-------+------+-------------+
        #   2 rows in set (0.00 sec)
        #
        # This is an exercise in Ruby hyperrealism :).
        def pp(result, elapsed)
          widths    = compute_column_widths(result)
          separator = build_separator(widths)

          pp = []

          pp << separator
          pp << build_cells(result.columns, widths)
          pp << separator

          result.rows.each do |row|
            pp << build_cells(row, widths)
          end

          pp << separator
          pp << build_footer(result.rows.length, elapsed)

          pp.join("\n") + "\n"
        end

        private
          def compute_column_widths(result)
            [].tap do |widths|
              result.columns.each_with_index do |column, i|
                cells_in_column = [column] + result.rows.map { |r| r[i].nil? ? "NULL" : r[i].to_s }
                widths << cells_in_column.map(&:length).max
              end
            end
          end

          def build_separator(widths)
            padding = 1
            "+" + widths.map { |w| "-" * (w + (padding * 2)) }.join("+") + "+"
          end

          def build_cells(items, widths)
            cells = []
            items.each_with_index do |item, i|
              item = "NULL" if item.nil?
              justifier = item.is_a?(Numeric) ? "rjust" : "ljust"
              cells << item.to_s.public_send(justifier, widths[i])
            end
            "| " + cells.join(" | ") + " |"
          end

          def build_footer(nrows, elapsed)
            rows_label = nrows == 1 ? "row" : "rows"
            "#{nrows} #{rows_label} in set (%.2f sec)" % elapsed
          end
      end
    end
  end
end
