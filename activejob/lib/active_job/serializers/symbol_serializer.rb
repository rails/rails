# frozen_string_literal: true

module ActiveJob
  module Serializers
    class SymbolSerializer < ObjectSerializer # :nodoc:
      def serialize(argument)
        super("value" => argument.name)
      end

      def deserialize(argument)
        argument["value"].to_sym
      end

      def klass
        Symbol
      end
    end
  end
end
