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
        end
      end
    end
  end
end
