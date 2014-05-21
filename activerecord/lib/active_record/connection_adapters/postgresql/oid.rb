require 'active_record/connection_adapters/postgresql/oid/infinity'

require 'active_record/connection_adapters/postgresql/oid/array'
require 'active_record/connection_adapters/postgresql/oid/bit'
require 'active_record/connection_adapters/postgresql/oid/bytea'
require 'active_record/connection_adapters/postgresql/oid/cidr'
require 'active_record/connection_adapters/postgresql/oid/date'
require 'active_record/connection_adapters/postgresql/oid/date_time'
require 'active_record/connection_adapters/postgresql/oid/decimal'
require 'active_record/connection_adapters/postgresql/oid/enum'
require 'active_record/connection_adapters/postgresql/oid/float'
require 'active_record/connection_adapters/postgresql/oid/hstore'
require 'active_record/connection_adapters/postgresql/oid/inet'
require 'active_record/connection_adapters/postgresql/oid/integer'
require 'active_record/connection_adapters/postgresql/oid/json'
require 'active_record/connection_adapters/postgresql/oid/money'
require 'active_record/connection_adapters/postgresql/oid/point'
require 'active_record/connection_adapters/postgresql/oid/range'
require 'active_record/connection_adapters/postgresql/oid/specialized_string'
require 'active_record/connection_adapters/postgresql/oid/time'
require 'active_record/connection_adapters/postgresql/oid/uuid'
require 'active_record/connection_adapters/postgresql/oid/vector'

require 'active_record/connection_adapters/postgresql/oid/type_map_initializer'

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
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
