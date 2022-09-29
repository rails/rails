# frozen_string_literal: true

require "active_model/attribute"

module ActiveModel
  class Attribute # :nodoc:
    def with_user_default(value)
      UserProvidedDefault.new(name, value, type, self.is_a?(FromDatabase) ? self : original_attribute)
    end

    class UserProvidedDefault < FromUser # :nodoc:
      def initialize(name, value, type, database_default)
        @user_provided_value = value
        super(name, value, type, database_default)
      end

      def value_before_type_cast
        if defined?(@memoized_value_before_type_cast)
          @memoized_value_before_type_cast
        elsif user_provided_value.is_a?(Proc)
          @memoized_value_before_type_cast = user_provided_value.call
        else
          @user_provided_value
        end
      end

      def with_value_from_user(value)
        type.assert_valid_value(value)
        if defined?(@memoized_value_before_type_cast) || !user_provided_value.is_a?(Proc)
          self.class.from_user(name, value, type, original_attribute || self)
        else
          self.class.from_user(name, value, type, original_attribute)
        end
      end

      def with_type(type)
        self.class.new(name, user_provided_value, type, original_attribute)
      end

      def marshal_dump
        result = [
          name,
          value_before_type_cast,
          type,
          original_attribute,
        ]
        result << value if defined?(@value)
        result
      end

      def marshal_load(values)
        name, user_provided_value, type, original_attribute, value = values
        @name = name
        @user_provided_value = user_provided_value
        @type = type
        @original_attribute = original_attribute
        if values.length == 5
          @value = value
        end
      end

      private
        attr_reader :user_provided_value
    end
  end
end
