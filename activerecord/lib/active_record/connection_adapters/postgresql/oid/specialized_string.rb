# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class SpecializedString < Type::String # :nodoc:
          attr_reader :type

          def initialize(type, **options)
            @type = type
            super(**options)
          end

          def as_schema_json
            json = super
            json["type"] = @type
            json
          end

          def init_from_schema_json(coder, references)
            super
            @type = coder["type"]&.to_sym
          end
        end
      end
    end
  end
end
