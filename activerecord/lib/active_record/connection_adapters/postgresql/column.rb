# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class Column < ConnectionAdapters::Column # :nodoc:
        delegate :oid, :fmod, to: :sql_type_metadata

        def initialize(*, serial: nil, identity: nil, generated: nil, **)
          super
          @serial = serial
          @identity = identity
          @generated = generated
        end

        def identity?
          @identity
        end

        def serial?
          @serial
        end

        def auto_incremented_by_db?
          serial? || identity?
        end

        def virtual?
          # We assume every generated column is virtual, no matter the concrete type
          @generated.present?
        end

        def virtual_stored?
          @generated == "s"
        end

        def has_default?
          super && !virtual?
        end

        def array
          sql_type_metadata.sql_type.end_with?("[]")
        end
        alias :array? :array

        def enum?
          type == :enum
        end

        def sql_type
          super.delete_suffix("[]")
        end

        def init_with(coder)
          @serial = coder["serial"]
          @identity = coder["identity"]
          @generated = coder["generated"]
          super
        end

        def encode_with(coder)
          coder["serial"] = @serial
          coder["identity"] = @identity
          coder["generated"] = @generated
          super
        end

        def ==(other)
          other.is_a?(Column) &&
            super &&
            identity? == other.identity? &&
            serial? == other.serial? &&
            virtual? == other.virtual?
        end
        alias :eql? :==

        def hash
          [
            Column,
            super,
            @identity,
            @serial,
            @generated,
          ].hash
        end
      end
    end
    PostgreSQLColumn = PostgreSQL::Column # :nodoc:
  end
end
