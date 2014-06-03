module ActiveRecord
  module Type
    class Binary < Value # :nodoc:
      def type
        :binary
      end

      def binary?
        true
      end

      def klass
        ::String
      end

      def type_cast_for_database(value)
        Data.new(super)
      end

      class Data
        def initialize(value)
          @value = value
        end

        def to_s
          @value
        end

        def hex
          @value.unpack('H*')[0]
        end
      end
    end
  end
end
