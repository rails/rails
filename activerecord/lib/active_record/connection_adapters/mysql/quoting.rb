module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Quoting # :nodoc:
        private

        def _quote(value)
          if value.is_a?(Type::Binary::Data)
            "x'#{value.hex}'"
          else
            super
          end
        end
      end
    end
  end
end
