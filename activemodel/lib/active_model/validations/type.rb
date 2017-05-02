module ActiveModel

  module Validations
    class TypeValidator < ActiveModel::EachValidator
      def validate_each(record, attr_name, value)
        record.errors.add(attr_name, :type, options) unless
          value.class == String and record.class.parent.descendants.include?(value.safe_constantize)
      end
    end
  end
end
