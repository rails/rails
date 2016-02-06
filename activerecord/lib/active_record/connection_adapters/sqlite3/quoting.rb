module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module Quoting # :nodoc:
        def quote_column_name(name)
          @quoted_column_names[name] ||= %Q("#{super.gsub('"', '""')}")
        end

        private

        def _quote(value)
          if value.is_a?(Type::Binary::Data)
            "x'#{value.hex}'"
          else
            super
          end
        end

        def _type_cast(value)
          case value
          when BigDecimal
            value.to_f
          when String
            if value.encoding == Encoding::ASCII_8BIT
              super(value.encode(Encoding::UTF_8))
            else
              super
            end
          else
            super
          end
        end
      end
    end
  end
end
