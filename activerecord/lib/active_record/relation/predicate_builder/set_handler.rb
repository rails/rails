module ActiveRecord
  class PredicateBuilder
    class SetHandler < ArrayHandler# :nodoc:
      def call(attribute, value)
        super(attribute, value.to_a)
      end
    end
  end
end
