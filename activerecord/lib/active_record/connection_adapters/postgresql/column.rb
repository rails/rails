# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class Column < ConnectionAdapters::Column # :nodoc:
        delegate :array, :oid, :fmod, to: :sql_type_metadata
        alias :array? :array

        def initialize(*, serial: nil, **)
          super
          @serial = serial
        end

        def serial?
          @serial
        end
      end
    end
    PostgreSQLColumn = PostgreSQL::Column # :nodoc:
  end
end
