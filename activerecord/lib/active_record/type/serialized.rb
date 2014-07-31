module ActiveRecord
  module Type
    class Serialized < SimpleDelegator # :nodoc:
      include Mutable

      attr_reader :subtype, :coder

      def initialize(subtype, coder)
        @subtype = subtype
        @coder = coder
        super(subtype)
      end

      def type_cast_from_database(value)
        if default_value?(value)
          value
        else
          coder.load(super)
        end
      end

      def type_cast_for_database(value)
        return if value.nil?
        unless default_value?(value)
          super coder.dump(value)
        end
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end

      def init_with(coder)
        @subtype = coder['subtype']
        @coder = coder['coder']
        __setobj__(@subtype)
      end

      def encode_with(coder)
        coder['subtype'] = @subtype
        coder['coder'] = @coder
      end

      private

      def default_value?(value)
        value == coder.load(nil)
      end
    end
  end
end
