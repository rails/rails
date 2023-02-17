# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class Column < ConnectionAdapters::Column # :nodoc:
        def initialize(*, auto_increment: nil, **)
          super
          @auto_increment = auto_increment
        end

        def auto_increment?
          @auto_increment
        end

        def init_with(coder)
          @auto_increment = coder["auto_increment"]
          super
        end

        def encode_with(coder)
          coder["auto_increment"] = @auto_increment
          super
        end

        def ==(other)
          other.is_a?(Column) &&
            super &&
            auto_increment? == other.auto_increment?
        end
        alias :eql? :==

        def hash
          Column.hash ^
            super.hash ^
            auto_increment?.hash
        end
      end
    end
  end
end
