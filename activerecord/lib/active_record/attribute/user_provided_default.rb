require 'active_record/attribute'

module ActiveRecord
  class Attribute # :nodoc:
    class UserProvidedDefault < FromUser
      def initialize(name, value, type, database_default)
        super(name, value, type)
        @database_default = database_default
      end

      def type_cast(value)
        if value.is_a?(Proc)
          super(value.call)
        else
          super
        end
      end

      def changed_from?(old_value)
        super || changed_from?(database_default.value)
      end

      def with_type(type)
        self.class.new(name, value_before_type_cast, type, database_default)
      end

      protected

      attr_reader :database_default
    end
  end
end
