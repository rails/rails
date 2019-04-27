# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class Column < ConnectionAdapters::Column # :nodoc:
        delegate :oid, :fmod, to: :sql_type_metadata

        def initialize(*, serial: nil, **)
          super
          @serial = serial
        end

        def serial?
          @serial
        end

        def array
          sql_type_metadata.sql_type.end_with?("[]")
        end
        alias :array? :array

        def sql_type
          super.sub(/\[\]\z/, "")
        end
      end
    end
    PostgreSQLColumn = PostgreSQL::Column # :nodoc:
  end
end
