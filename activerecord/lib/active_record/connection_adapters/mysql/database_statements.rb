# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module DatabaseStatements
        READ_QUERY = AbstractAdapter.build_read_query_regexp(
          :desc, :describe, :set, :show, :use, :kill
        ) # :nodoc:
        private_constant :READ_QUERY

        # https://dev.mysql.com/doc/refman/5.7/en/date-and-time-functions.html#function_current-timestamp
        # https://dev.mysql.com/doc/refman/5.7/en/date-and-time-type-syntax.html
        HIGH_PRECISION_CURRENT_TIMESTAMP = Arel.sql("CURRENT_TIMESTAMP(6)").freeze # :nodoc:
        private_constant :HIGH_PRECISION_CURRENT_TIMESTAMP

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        rescue ArgumentError # Invalid encoding
          !READ_QUERY.match?(sql.b)
        end

        def high_precision_current_timestamp
          HIGH_PRECISION_CURRENT_TIMESTAMP
        end

        def explain(arel, binds = [], options = [])
          sql     = build_explain_clause(options) + " " + to_sql(arel, binds)
          start   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result  = internal_exec_query(sql, "EXPLAIN", binds)
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

          MySQL::ExplainPrettyPrinter.new.pp(result, elapsed)
        end

        def build_explain_clause(options = [])
          return "EXPLAIN" if options.empty?

          explain_clause = "EXPLAIN #{options.join(" ").upcase}"

          if analyze_without_explain? && explain_clause.include?("ANALYZE")
            explain_clause.sub("EXPLAIN ", "")
          else
            explain_clause
          end
        end

        private
          # https://mariadb.com/kb/en/analyze-statement/
          def analyze_without_explain?
            mariadb? && database_version >= "10.1.0"
          end

          def default_insert_value(column)
            super unless column.auto_increment?
          end

          def combine_multi_statements(total_sql)
            total_sql.each_with_object([]) do |sql, total_sql_chunks|
              previous_packet = total_sql_chunks.last
              if max_allowed_packet_reached?(sql, previous_packet)
                total_sql_chunks << +sql
              else
                previous_packet << ";\n"
                previous_packet << sql
              end
            end
          end

          def max_allowed_packet_reached?(current_packet, previous_packet)
            if current_packet.bytesize > max_allowed_packet
              raise ActiveRecordError,
                "Fixtures set is too large #{current_packet.bytesize}. Consider increasing the max_allowed_packet variable."
            elsif previous_packet.nil?
              true
            else
              (current_packet.bytesize + previous_packet.bytesize + 2) > max_allowed_packet
            end
          end

          def max_allowed_packet
            @max_allowed_packet ||= show_variable("max_allowed_packet")
          end
      end
    end
  end
end
