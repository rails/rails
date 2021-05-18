# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class Json < Type::Json # :nodoc:
        class NumericSQLValue < ::Numeric # :nodoc:
          attr_reader :numeric

          def initialize(numeric)
            raise ArgumentError, "expected #{numeric.inspect} to be Numeric" unless numeric.is_a?(Numeric)
            @numeric = numeric
          end

          # MySQL adapter has no separate binds, it quotes values inline.
          # This affects case if (and only if) we pass explicit numeric as a value for `json` column in `where`
          #
          # Note, the following queries are different
          # SELECT ... WHERE `json_data_type`.`payload` = 42                 # a MySQL query in repl, finds correctly
          # SELECT ... WHERE `json_data_type`.`payload` = CAST('42' AS json) # rendered NumericValue, finds correctly
          #
          # But parent Type::Json#serialize returned json-string, it gets quoted, finds nothing
          # SELECT ... WHERE `json_data_type`.`payload` = '42'
          #
          # According to RFC8259 a json top level value defined as:
          # value = false / null / true / object / array / number / string
          # MySQL behaves correctly when making the difference
          #
          # Besides, we cannot return numeric value from #serialize,
          # it breaks insertion, the following is invalid:
          # INSERT INTO `json_data_type` (`payload`) VALUES (42)
          #
          # On the contrary, SQL part with `CAST` is fine
          # i.e. if (and only if) we pass explicit numeric as a value for `json` column in `create`, we'll get
          # INSERT INTO `json_data_type` (`payload`) VALUES (CAST('42' AS json))
          #
          # To run a query which properly compares a `json` field with a single integer, which is valid operation,
          # we have to return an instance of this class and rely on `quoter` to call `to_s` on it.
          # It does the same with `when Numeric`, see ActiveRecord::ConnectionAdapters::Mysql2Adapter#_quote(value)
          def to_s
            "CAST('#{@numeric}' AS json)"
          end
        end
        private_constant :NumericSQLValue

        def type
          :json
        end

        def cast(value)
          return value if numeric?(value)
          super
        end

        def serialize(value)
          return NumericSQLValue.new(value) if numeric?(value)
          super
        end

        def deserialize(value)
          return value.numeric if value.is_a?(NumericSQLValue)
          super
        end

        private
          def numeric?(value)
            value.is_a?(::Integer) || value.is_a?(::Float)
          end
      end
    end
  end
end
