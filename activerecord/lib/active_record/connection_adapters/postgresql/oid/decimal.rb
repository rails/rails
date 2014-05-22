module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Decimal < Type::Decimal
          def infinity(options = {})
            BigDecimal.new("Infinity") * (options[:negative] ? -1 : 1)
          end
        end
      end
    end
  end
end
