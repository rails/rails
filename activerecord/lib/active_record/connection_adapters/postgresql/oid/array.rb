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
              type_cast_array(parse_pg_array(value))
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

          def type_cast_array(value)
            if value.is_a?(::Array)
              value.map { |item| type_cast_array(item) }
            else
              @subtype.type_cast_from_database(value)
            end
          end
        end
      end
    end
  end
end
