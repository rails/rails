module ActiveRecord
  module Validations
    class PresenceValidator < ActiveModel::Validations::PresenceValidator # :nodoc:
      def validate(record)
        attributes.each do |attribute|
          begin
            reflection = record.class._reflect_on_association(attribute)
            validate_attribute_presence(record, attribute)
            validate_association_persistence(record, attribute) if reflection
          rescue RangeError
            record.errors.add(reflection ? reflection.foreign_key : attribute, :invalid, options)
          end
        end
      end

      protected

      def validate_attribute_presence(record, attribute)
        value = record.read_attribute_for_validation(attribute)
        return if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
        validate_each(record, attribute, value)
      end

      def validate_association_persistence(record, attribute)
        associated_records = Array.wrap(record.read_attribute_for_validation(attribute))
        # validate_attribute_presence validates presence. Ensure all present records aren't about to be destroyed.
        return if associated_records.blank? || associated_records.any? { |r| !r.marked_for_destruction? }
        record.errors.add(attribute, :blank, options)
      end
    end

    module ClassMethods
      # Validates that the specified attributes are not blank (as defined by
      # Object#blank?), and, if the attribute is an association, that the
      # associated object is not marked for destruction. Happens by default
      # on save.
      #
      #   class Person < ActiveRecord::Base
      #     has_one :face
      #     validates_presence_of :face
      #   end
      #
      # The face attribute must be in the object and it cannot be blank or marked
      # for destruction.
      #
      # If you want to validate the presence of a boolean field (where the real values
      # are true and false), you will want to use
      # <tt>validates_inclusion_of :field_name, in: [true, false]</tt>.
      #
      # This is due to the way Object#blank? handles boolean values:
      # <tt>false.blank? # => true</tt>.
      #
      # This validator defers to the ActiveModel validation for presence, adding the
      # check to see that an associated object is not marked for destruction. This
      # prevents the parent object from validating successfully and saving, which then
      # deletes the associated object, thus putting the parent object into an invalid
      # state.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "can't be blank").
      # * <tt>:on</tt> - Specifies the contexts where this validation is active.
      #   Runs in all validation contexts by default (nil). You can pass a symbol
      #   or an array of symbols. (e.g. <tt>on: :create</tt> or
      #   <tt>on: :custom_validation_context</tt> or
      #   <tt>on: [:create, :custom_validation_context]</tt>)
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if
      #   the validation should occur (e.g. <tt>if: :allow_validation</tt>, or
      #   <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method, proc
      #   or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:strict</tt> - Specifies whether validation should be strict.
      #   See <tt>ActiveModel::Validation#validates!</tt> for more information.
      def validates_presence_of(*attr_names)
        validates_with PresenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
