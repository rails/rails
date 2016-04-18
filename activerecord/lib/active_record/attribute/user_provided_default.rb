require 'active_record/attribute'

module ActiveRecord
  class Attribute # :nodoc:
    class UserProvidedDefault < FromUser # :nodoc:
      def initialize(name, value, type, database_default)
        @user_provided_value = value
        super(name, value, type, database_default)
      end

      def value_before_type_cast
        if user_provided_value.is_a?(Proc)
          @memoized_value_before_type_cast ||= user_provided_value.call
        else
          @user_provided_value
        end
      end

      def with_type(type)
        self.class.new(name, user_provided_value, type, original_attribute)
      end

      protected

      attr_reader :user_provided_value
    end
  end
end
