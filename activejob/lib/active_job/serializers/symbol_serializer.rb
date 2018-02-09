module ActiveJob
  module Serializers
    class SymbolSerializer < ObjectSerializer # :nodoc:
      def serialize(argument)
        super("value" => argument.to_s)
      end

      def deserialize(argument)
        argument["value"].to_sym
      end

      private

        def klass
          Symbol
        end
    end
  end
end
