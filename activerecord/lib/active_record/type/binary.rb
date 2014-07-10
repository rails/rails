module ActiveRecord
  module Type
    class Binary < Value # :nodoc:
      def type
        :binary
      end

      def binary?
        true
      end

      def type_cast(value)
        if value.is_a?(Data)
          value.to_s
        else
          super
        end
      end

      def type_cast_for_database(value)
        return if value.nil?
        Data.new(super)
      end

      class Data # :nodoc:
        def initialize(value)
          @value = value.to_s
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
