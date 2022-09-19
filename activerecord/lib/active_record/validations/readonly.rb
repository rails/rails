# frozen_string_literal: true

module ActiveRecord
  module Validations
    class ReadonlyValidator < ActiveModel::EachValidator # :nodoc:
      def validate_each(record, attribute, _value)
        if record.persisted? && record.attribute_changed?(attribute_name(record, attribute))
          record.errors.add(attribute, "is readonly")
        end
      end

      private
        def attribute_name(record, attribute)
          reflection = record.class._reflect_on_association(attribute)

          if reflection.nil?
            attribute.to_s
          else
            reflection.foreign_key
          end
        end
    end
  end
end
