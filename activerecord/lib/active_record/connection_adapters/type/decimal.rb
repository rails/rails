module ActiveRecord
  module ConnectionAdapters
    module Type
      class Decimal < Value # :nodoc:
        include Numeric

        attr_reader :scale

        def initialize(scale)
          @scale = scale
        end

        def type
          :decimal
        end

        def klass
          ::BigDecimal
        end

        private

        def cast_value(value)
          if value.respond_to?(:to_d)
            value.to_d
          else
            value.to_s.to_d
          end
        end
      end
    end
  end
end
