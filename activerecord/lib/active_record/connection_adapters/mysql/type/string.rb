module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Type
        class String < ActiveRecord::Type::String # :nodoc:
          def serialize(value)
            case value
            when true then "1"
            when false then "0"
            else super
            end
          end

          private

          def cast_value(value)
            case value
            when true then "1"
            when false then "0"
            else super
            end
          end
        end
      end
    end
  end
end
