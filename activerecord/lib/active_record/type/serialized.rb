module ActiveRecord
  module Type
    class Serialized < SimpleDelegator # :nodoc:
      attr_reader :subtype, :coder

      def initialize(subtype, coder)
        @subtype = subtype
        @coder = coder
        super(subtype)
      end

      def type_cast(value)
        if value.respond_to?(:unserialized_value)
          value.unserialized_value(super(value.value))
        else
          super
        end
      end

      def type_cast_for_write(value)
        Attribute.new(coder, value, :unserialized)
      end

      def raw_type_cast_for_write(value)
        Attribute.new(coder, value, :serialized)
      end

      def serialized?
        true
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end

      class Attribute < Struct.new(:coder, :value, :state) # :nodoc:
        def unserialized_value(v = value)
          state == :serialized ? unserialize(v) : value
        end

        def serialized_value
          state == :unserialized ? serialize : value
        end

        def unserialize(v)
          self.state = :unserialized
          self.value = coder.load(v)
        end

        def serialize
          self.state = :serialized
          self.value = coder.dump(value)
        end
      end
    end
  end
end
