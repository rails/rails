module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Integer < Type::Integer # :nodoc:
          def initialize(*)
            super
            @range = min_value...max_value
          end

          def cover?(value)
            @range.cover?(value)
          end

          private

            def max_value
              if limit
                1 << (limit * 8 - 1) # 8 bits per byte with one bit for sign
              else
                ::Float::INFINITY
              end
            end

            def min_value
              -max_value
            end
        end
      end
    end
  end
end
