require 'active_record/connection_adapters/abstract_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      module OID
        class Type
          def type; end

          def type_cast_for_write(value)
            value
          end
        end

        class Identity < Type
          def type_cast(value)
            value
          end
        end

        class Bytea < Type
          def type_cast(value)
            PGconn.unescape_bytea value
          end
        end

        class Money < Type
          def type_cast(value)
            return if value.nil?

            # Because money output is formatted according to the locale, there are two
            # cases to consider (note the decimal separators):
            #  (1) $12,345,678.12
            #  (2) $12.345.678,12

            case value
            when /^-?\D+[\d,]+\.\d{2}$/  # (1)
              value.gsub!(/[^-\d.]/, '')
            when /^-?\D+[\d.]+,\d{2}$/  # (2)
              value.gsub!(/[^-\d,]/, '').sub!(/,/, '.')
            end

            ConnectionAdapters::Column.value_to_decimal value
          end
        end

        class Vector < Type
          attr_reader :delim, :subtype

          # +delim+ corresponds to the `typdelim` column in the pg_types
          # table.  +subtype+ is derived from the `typelem` column in the
          # pg_types table.
          def initialize(delim, subtype)
            @delim   = delim
            @subtype = subtype
          end

          # FIXME: this should probably split on +delim+ and use +subtype+
          # to cast the values.  Unfortunately, the current Rails behavior
          # is to just return the string.
          def type_cast(value)
            value
          end
        end

        class Integer < Type
          def type_cast(value)
            return if value.nil?

            value.to_i rescue value ? 1 : 0
          end
        end

        class Boolean < Type
          def type_cast(value)
            return if value.nil?

            ConnectionAdapters::Column.value_to_boolean value
          end
        end

        class Timestamp < Type
          def type; :timestamp; end

          def type_cast(value)
            return if value.nil?

            # FIXME: probably we can improve this since we know it is PG
            # specific
            ConnectionAdapters::PostgreSQLColumn.string_to_time value
          end
        end

        class Date < Type
          def type; :datetime; end

          def type_cast(value)
            return if value.nil?

            # FIXME: probably we can improve this since we know it is PG
            # specific
            ConnectionAdapters::Column.value_to_date value
          end
        end

        class Time < Type
          def type_cast(value)
            return if value.nil?

            # FIXME: probably we can improve this since we know it is PG
            # specific
            ConnectionAdapters::Column.string_to_dummy_time value
          end
        end

        class Float < Type
          def type_cast(value)
            return if value.nil?

            value.to_f
          end
        end

        class Decimal < Type
          def type_cast(value)
            return if value.nil?

            ConnectionAdapters::Column.value_to_decimal value
          end
        end

        class Hstore < Type
          def type_cast(value)
            return if value.nil?

            ConnectionAdapters::PostgreSQLColumn.string_to_hstore value
          end
        end

        class Cidr < Type
          def type_cast(value)
            return if value.nil?

            ConnectionAdapters::PostgreSQLColumn.string_to_cidr value
          end
        end

        class Json < Type
          def type_cast(value)
            return if value.nil?

            ConnectionAdapters::PostgreSQLColumn.string_to_json value
          end
        end

        class TypeMap
          def initialize
            @mapping = {}
          end

          def []=(oid, type)
            @mapping[oid] = type
          end

          def [](oid)
            @mapping[oid]
          end

          def key?(oid)
            @mapping.key? oid
          end

          def fetch(ftype, fmod)
            # The type for the numeric depends on the width of the field,
            # so we'll do something special here.
            #
            # When dealing with decimal columns:
            #
            # places after decimal  = fmod - 4 & 0xffff
            # places before decimal = (fmod - 4) >> 16 & 0xffff
            if ftype == 1700 && (fmod - 4 & 0xffff).zero?
              ftype = 23
            end

            @mapping.fetch(ftype) { |oid| yield oid, fmod }
          end
        end

        TYPE_MAP = TypeMap.new # :nodoc:

        # When the PG adapter connects, the pg_type table is queried.  The
        # key of this hash maps to the `typname` column from the table.
        # TYPE_MAP is then dynamically built with oids as the key and type
        # objects as values.
        NAMES = Hash.new { |h,k| # :nodoc:
          h[k] = OID::Identity.new
        }

        # Register an OID type named +name+ with a typcasting object in
        # +type+.  +name+ should correspond to the `typname` column in
        # the `pg_type` table.
        def self.register_type(name, type)
          NAMES[name] = type
        end

        # Alias the +old+ type to the +new+ type.
        def self.alias_type(new, old)
          NAMES[new] = NAMES[old]
        end

        # Is +name+ a registered type?
        def self.registered_type?(name)
          NAMES.key? name
        end

        register_type 'int2', OID::Integer.new
        alias_type    'int4', 'int2'
        alias_type    'int8', 'int2'
        alias_type    'oid',  'int2'

        register_type 'numeric', OID::Decimal.new
        register_type 'text', OID::Identity.new
        alias_type 'varchar', 'text'
        alias_type 'char', 'text'
        alias_type 'bpchar', 'text'
        alias_type 'xml', 'text'

        # FIXME: why are we keeping these types as strings?
        alias_type 'tsvector', 'text'
        alias_type 'interval', 'text'
        alias_type 'bit',      'text'
        alias_type 'varbit',   'text'
        alias_type 'macaddr',  'text'
        alias_type 'uuid',     'text'

        # FIXME: I don't think this is correct. We should probably be returning a parsed date,
        # but the tests pass with a string returned.
        register_type 'timestamptz', OID::Identity.new

        register_type 'money', OID::Money.new
        register_type 'bytea', OID::Bytea.new
        register_type 'bool', OID::Boolean.new

        register_type 'float4', OID::Float.new
        alias_type 'float8', 'float4'

        register_type 'timestamp', OID::Timestamp.new
        register_type 'date', OID::Date.new
        register_type 'time', OID::Time.new

        register_type 'path', OID::Identity.new
        register_type 'polygon', OID::Identity.new
        register_type 'circle', OID::Identity.new
        register_type 'hstore', OID::Hstore.new
        register_type 'json', OID::Json.new

        register_type 'cidr', OID::Cidr.new
        alias_type 'inet', 'cidr'
      end
    end
  end
end
