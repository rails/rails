module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Array < Type::Value # :nodoc:
          include Type::Mutable

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

          attr_reader :subtype, :delimiter
          delegate :type, :limit, to: :subtype

          def initialize(subtype, delimiter = ',')
            @subtype = subtype
            @delimiter = delimiter
          end

          def type_cast_from_database(value)
            if value.is_a?(::String)
              type_cast_array(parse_pg_array(value), :type_cast_from_database)
            else
              super
            end
          end

          def type_cast_from_user(value)
            if value.is_a?(::String)
              value = parse_pg_array(value)
            end
            type_cast_array(value, :type_cast_from_user)
          end

          def type_cast_for_database(value)
            if value.is_a?(::Array)
              cast_value_for_database(value)
            else
              super
            end
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
              "{#{casted_values.join(delimiter)}}"
            else
              quote_and_escape(subtype.type_cast_for_database(value))
            end
          end

          ARRAY_ESCAPE = "\\" * 2 * 2 # escape the backslash twice for PG arrays

          def quote_and_escape(value)
            case value
            when ::String
              if string_requires_quoting?(value)
                value = value.gsub(/\\/, ARRAY_ESCAPE)
                value.gsub!(/"/,"\\\"")
                %("#{value}")
              else
                value
              end
            when nil then "NULL"
            when ::Date, ::DateTime, ::Time then subtype.type_cast_for_schema(value)
            else value
            end
          end

          # See http://www.postgresql.org/docs/9.2/static/arrays.html#ARRAYS-IO
          # for a list of all cases in which strings will be quoted.
          def string_requires_quoting?(string)
            string.empty? ||
              string == "NULL" ||
              string =~ /[\{\}"\\\s]/ ||
              string.include?(delimiter)
          end
        end
      end
    end
  end
end
