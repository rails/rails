require 'active_record/attribute'

module ActiveRecord
  class Attribute # :nodoc:
    class UserProvidedDefault < FromUser # :nodoc:
      def initialize(name, value, type, database_default)
        super(name, value, type, database_default)
      end

      def type_cast(value)
        if value.is_a?(Proc)
          super(value.call)
        else
          super
        end
      end

      def with_type(type)
        self.class.new(name, value_before_type_cast, type, original_attribute)
      end
    end
  end
end
