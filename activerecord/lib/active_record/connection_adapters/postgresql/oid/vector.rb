# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Vector < Type::Value # :nodoc:
          attr_reader :delim, :subtype

          # +delim+ corresponds to the `typdelim` column in the pg_types
          # table.  +subtype+ is derived from the `typelem` column in the
          # pg_types table.
          def initialize(delim, subtype)
            @delim   = delim
            @subtype = subtype
          end

          def as_schema_json
            { "delim" => delim, "subtype" => subtype }
          end

          def init_from_schema_json(coder, references)
            @delim = coder["delim"]
            @subtype = references[coder["subtype"]]
          end

          # FIXME: this should probably split on +delim+ and use +subtype+
          # to cast the values.  Unfortunately, the current Rails behavior
          # is to just return the string.
          def cast(value)
            value
          end
        end
      end
    end
  end
end
