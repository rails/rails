# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class LegacyPoint < Type::Value # :nodoc:
          include ActiveModel::Type::Helpers::Mutable

          def type
            :point
          end

          def cast(value)
            case value
            when ::String
              if value.start_with?("(") && value.end_with?(")")
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
              number.to_s.delete_suffix(".0")
            end
        end
      end
    end
  end
end
