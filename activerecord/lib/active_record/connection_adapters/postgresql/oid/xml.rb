# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Xml < Type::String # :nodoc:
          def type
            :xml
          end

          def serialize(value)
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
