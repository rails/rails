module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Array < Type::Value
          attr_reader :subtype
          delegate :type, to: :subtype

          def initialize(subtype)
            @subtype = subtype
          end

          def type_cast_from_database(value)
            if value.is_a?(::String)
              type_cast_array(parse_pg_array(value), :type_cast_from_database)
            else
              super
            end
          end

          def type_cast_from_user(value)
            type_cast_array(value, :type_cast_from_user)
          end

          def type_cast_for_database(value)
            if value.is_a?(::Array)
              cast_value_for_database(value)
            else
              super
            end
          end

          # Loads pg_array_parser if available. String parsing can be
          # performed quicker by a native extension, which will not create
          # a large amount of Ruby objects that will need to be garbage
          # collected. pg_array_parser has a C and Java extension
          begin
            require 'pg_array_parser'
            include PgArrayParser
          rescue LoadError
            require 'active_record/connection_adapters/postgresql/array_parser'
            include PostgreSQL::ArrayParser
          end

          private

          def type_cast_array(value, method)
            if value.is_a?(::Array)
              value.map { |item| type_cast_array(item, method) }
            else
              @subtype.public_send(method, value)
            end
          end

          def cast_value_for_database(value)
            if value.is_a?(::Array)
              casted_values = value.map { |item| cast_value_for_database(item) }
              "{#{casted_values.join(',')}}"
            else
              quote_and_escape(subtype.type_cast_for_database(value))
            end
          end

          ARRAY_ESCAPE = "\\" * 2 * 2 # escape the backslash twice for PG arrays

          def quote_and_escape(value)
            case value
            when ::String
              value = value.gsub(/\\/, ARRAY_ESCAPE)
              value.gsub!(/"/,"\\\"")
              %("#{value}")
            when nil then "NULL"
            else value
            end
          end
        end
      end
    end
  end
end
