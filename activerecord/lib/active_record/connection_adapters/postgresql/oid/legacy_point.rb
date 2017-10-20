# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class LegacyPoint < Type::Value # :nodoc:
          include Type::Helpers::Mutable

          def type
            :point
          end

          def cast(value)
            case value
            when ::String
              if value[0] == "(" && value[-1] == ")"
                value = value[1...-1]
              end
              cast(value.split(","))
            when ::Array
              value.map { |v| Float(v) }
            else
              value
            end
          end

          def serialize(value)
            if value.is_a?(::Array)
              "(#{number_for_point(value[0])},#{number_for_point(value[1])})"
            else
              super
            end
          end

          private

            def number_for_point(number)
              number.to_s.gsub(/\.0$/, "")
            end
        end
      end
    end
  end
end
