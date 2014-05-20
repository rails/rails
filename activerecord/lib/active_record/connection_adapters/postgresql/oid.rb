module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        module Infinity
          def infinity(options = {})
            options[:negative] ? -::Float::INFINITY : ::Float::INFINITY
          end
        end

        class SpecializedString < Type::String
          attr_reader :type

          def initialize(type)
            @type = type
          end

          def text?
            false
          end
        end

        class Bit < Type::String
          def type_cast(value)
            if ::String === value
              ConnectionAdapters::PostgreSQLColumn.string_to_bit value
            else
              value
            end
          end
        end

        class Bytea < Type::Binary
          def cast_value(value)
            PGconn.unescape_bytea value
          end
        end

        class Money < Type::Decimal
          include Infinity

          def cast_value(value)
            return value unless ::String === value

            # Because money output is formatted according to the locale, there are two
            # cases to consider (note the decimal separators):
            #  (1) $12,345,678.12
            #  (2) $12.345.678,12
            # Negative values are represented as follows:
            #  (3) -$2.55
            #  (4) ($2.55)

            value.sub!(/^\((.+)\)$/, '-\1') # (4)
            case value
            when /^-?\D+[\d,]+\.\d{2}$/  # (1)
              value.gsub!(/[^-\d.]/, '')
            when /^-?\D+[\d.]+,\d{2}$/  # (2)
              value.gsub!(/[^-\d,]/, '').sub!(/,/, '.')
            end

            super(value)
          end
        end

        class Vector < Type::Value
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

        class Point < Type::String
          def type_cast(value)
            if ::String === value
              ConnectionAdapters::PostgreSQLColumn.string_to_point value
            else
              value
            end
          end
        end

        class Array < Type::Value
          attr_reader :subtype
          delegate :type, to: :subtype

          def initialize(subtype)
            @subtype = subtype
          end

          def type_cast(value)
            if ::String === value
              ConnectionAdapters::PostgreSQLColumn.string_to_array value, @subtype
            else
              value
            end
          end
        end

        class Range < Type::Value
          attr_reader :subtype, :type

          def initialize(subtype, type)
            @subtype = subtype
            @type = type
          end

          def extract_bounds(value)
            from, to = value[1..-2].split(',')
            {
              from:          (value[1] == ',' || from == '-infinity') ? @subtype.infinity(negative: true) : from,
              to:            (value[-2] == ',' || to == 'infinity') ? @subtype.infinity : to,
              exclude_start: (value[0] == '('),
              exclude_end:   (value[-1] == ')')
            }
          end

          def infinity?(value)
            value.respond_to?(:infinite?) && value.infinite?
          end

          def type_cast_single(value)
            infinity?(value) ? value : @subtype.type_cast(value)
          end

          def cast_value(value)
            return if value == 'empty'
            return value if value.is_a?(::Range)

            extracted = extract_bounds(value)
            from = type_cast_single extracted[:from]
            to = type_cast_single extracted[:to]

            if !infinity?(from) && extracted[:exclude_start]
              if from.respond_to?(:succ)
                from = from.succ
                ActiveSupport::Deprecation.warn <<-MESSAGE
Excluding the beginning of a Range is only partialy supported through `#succ`.
This is not reliable and will be removed in the future.
                MESSAGE
              else
                raise ArgumentError, "The Ruby Range object does not support excluding the beginning of a Range. (unsupported value: '#{value}')"
              end
            end
            ::Range.new(from, to, extracted[:exclude_end])
          end
        end

        class Integer < Type::Integer
          include Infinity
        end

        class DateTime < Type::DateTime
          include Infinity

          def cast_value(value)
            if value.is_a?(::String)
              case value
              when 'infinity' then ::Float::INFINITY
              when '-infinity' then -::Float::INFINITY
              when / BC$/
                super("-" + value.sub(/ BC$/, ""))
              else
                super
              end
            else
              value
            end
          end
        end

        class Date < Type::Date
          include Infinity
        end

        class Time < Type::Time
          include Infinity
        end

        class Float < Type::Float
          include Infinity

          def type_cast(value)
            case value
            when nil then         nil
            when 'Infinity' then  ::Float::INFINITY
            when '-Infinity' then -::Float::INFINITY
            when 'NaN' then       ::Float::NAN
            else                  value.to_f
            end
          end
        end

        class Decimal < Type::Decimal
          def infinity(options = {})
            BigDecimal.new("Infinity") * (options[:negative] ? -1 : 1)
          end
        end

        class Enum < Type::Value
          def type
            :enum
          end

          def type_cast(value)
            value.to_s
          end
        end

        class Hstore < Type::Value
          def type
            :hstore
          end

          def type_cast_for_write(value)
            ConnectionAdapters::PostgreSQLColumn.hstore_to_string value
          end

          def cast_value(value)
            ConnectionAdapters::PostgreSQLColumn.string_to_hstore value
          end

          def accessor
            ActiveRecord::Store::StringKeyedHashAccessor
          end
        end

        class Cidr < Type::Value
          def type
            :cidr
          end

          def cast_value(value)
            ConnectionAdapters::PostgreSQLColumn.string_to_cidr value
          end
        end

        class Inet < Cidr
          def type
            :inet
          end
        end

        class Json < Type::Value
          def type
            :json
          end

          def type_cast_for_write(value)
            ConnectionAdapters::PostgreSQLColumn.json_to_string value
          end

          def cast_value(value)
            ConnectionAdapters::PostgreSQLColumn.string_to_json value
          end

          def accessor
            ActiveRecord::Store::StringKeyedHashAccessor
          end
        end

        class Uuid < Type::Value
          def type
            :uuid
          end

          def type_cast(value)
            value.presence
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

          def clear
            @mapping.clear
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

        # This class uses the data from PostgreSQL pg_type table to build
        # the OID -> Type mapping.
        #   - OID is and integer representing the type.
        #   - Type is an OID::Type object.
        # This class has side effects on the +store+ passed during initialization.
        class TypeMapInitializer # :nodoc:
          def initialize(store)
            @store = store
          end

          def run(records)
            mapped, nodes = records.partition { |row| OID.registered_type? row['typname'] }
            ranges, nodes = nodes.partition { |row| row['typtype'] == 'r' }
            enums, nodes = nodes.partition { |row| row['typtype'] == 'e' }
            domains, nodes = nodes.partition { |row| row['typtype'] == 'd' }
            arrays, nodes = nodes.partition { |row| row['typinput'] == 'array_in' }
            composites, nodes = nodes.partition { |row| row['typelem'] != '0' }

            mapped.each     { |row| register_mapped_type(row)    }
            enums.each      { |row| register_enum_type(row)      }
            domains.each    { |row| register_domain_type(row)    }
            arrays.each     { |row| register_array_type(row)     }
            ranges.each     { |row| register_range_type(row)     }
            composites.each { |row| register_composite_type(row) }
          end

          private
          def register_mapped_type(row)
            register row['oid'], OID::NAMES[row['typname']]
          end

          def register_enum_type(row)
            register row['oid'], OID::Enum.new
          end

          def register_array_type(row)
            if subtype = @store[row['typelem'].to_i]
              register row['oid'], OID::Array.new(subtype)
            end
          end

          def register_range_type(row)
            if subtype = @store[row['rngsubtype'].to_i]
              register row['oid'], OID::Range.new(subtype, row['typname'].to_sym)
            end
          end

          def register_domain_type(row)
            if base_type = @store[row["typbasetype"].to_i]
              register row['oid'], base_type
            else
              warn "unknown base type (OID: #{row["typbasetype"]}) for domain #{row["typname"]}."
            end
          end

          def register_composite_type(row)
            if subtype = @store[row['typelem'].to_i]
              register row['oid'], OID::Vector.new(row['typdelim'], subtype)
            end
          end

          def register(oid, oid_type)
            oid = oid.to_i

            raise ArgumentError, "can't register nil type for OID #{oid}" if oid_type.nil?
            return if @store.key?(oid)

            @store[oid] = oid_type
          end
        end

        # When the PG adapter connects, the pg_type table is queried. The
        # key of this hash maps to the `typname` column from the table.
        # type_map is then dynamically built with oids as the key and type
        # objects as values.
        NAMES = Hash.new { |h,k| # :nodoc:
          h[k] = Type::Value.new
        }

        # Register an OID type named +name+ with a typecasting object in
        # +type+. +name+ should correspond to the `typname` column in
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
        alias_type 'int4', 'int2'
        alias_type 'int8', 'int2'
        alias_type 'oid', 'int2'
        register_type 'numeric', OID::Decimal.new
        register_type 'float4', OID::Float.new
        alias_type 'float8', 'float4'
        register_type 'text', Type::Text.new
        register_type 'varchar', Type::String.new
        alias_type 'char', 'varchar'
        alias_type 'name', 'varchar'
        alias_type 'bpchar', 'varchar'
        register_type 'bool', Type::Boolean.new
        register_type 'bit', OID::Bit.new
        alias_type 'varbit', 'bit'
        register_type 'timestamp', OID::DateTime.new
        alias_type 'timestamptz', 'timestamp'
        register_type 'date', OID::Date.new
        register_type 'time', OID::Time.new

        register_type 'money', OID::Money.new
        register_type 'bytea', OID::Bytea.new
        register_type 'point', OID::Point.new
        register_type 'hstore', OID::Hstore.new
        register_type 'json', OID::Json.new
        register_type 'cidr', OID::Cidr.new
        register_type 'inet', OID::Inet.new
        register_type 'uuid', OID::Uuid.new
        register_type 'xml', SpecializedString.new(:xml)
        register_type 'tsvector', SpecializedString.new(:tsvector)
        register_type 'macaddr', SpecializedString.new(:macaddr)
        register_type 'citext', SpecializedString.new(:citext)
        register_type 'ltree', SpecializedString.new(:ltree)

        # FIXME: why are we keeping these types as strings?
        alias_type 'interval', 'varchar'
        alias_type 'path', 'varchar'
        alias_type 'line', 'varchar'
        alias_type 'polygon', 'varchar'
        alias_type 'circle', 'varchar'
        alias_type 'lseg', 'varchar'
        alias_type 'box', 'varchar'
      end
    end
  end
end
