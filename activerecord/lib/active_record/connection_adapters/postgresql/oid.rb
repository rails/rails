require_relative "oid/array"
require_relative "oid/bit"
require_relative "oid/bit_varying"
require_relative "oid/bytea"
require_relative "oid/cidr"
require_relative "oid/date_time"
require_relative "oid/decimal"
require_relative "oid/enum"
require_relative "oid/hstore"
require_relative "oid/inet"
require_relative "oid/jsonb"
require_relative "oid/money"
require_relative "oid/oid"
require_relative "oid/point"
require_relative "oid/legacy_point"
require_relative "oid/range"
require_relative "oid/specialized_string"
require_relative "oid/uuid"
require_relative "oid/vector"
require_relative "oid/xml"

require_relative "oid/type_map_initializer"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
      end
    end
  end
end
