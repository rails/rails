module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Xml < Type::String # :nodoc:
          def type
            :xml
          end

          def type_cast_for_database(value)
            return unless value
            Data.new(super)
          end

          class Data # :nodoc:
            def initialize(value)
              @value = value
            end

            def to_s
              @value
            end
          end
        end
      end
    end
  end
end
