module ActiveRecord
  module Validations
    class PresenceValidator < ActiveModel::Validations::PresenceValidator # :nodoc:
      def validate_each(record, attribute, association_or_value)
        if record.class._reflect_on_association(attribute)
          association_or_value = Array.wrap(association_or_value).reject(&:marked_for_destruction?)
        end
        super
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
      # This validator defers to the Active Model validation for presence, adding the
      # check to see that an associated object is not marked for destruction. This
      # prevents the parent object from validating successfully and saving, which then
      # deletes the associated object, thus putting the parent object into an invalid
      # state.
      #
      # NOTE: This validation will not fail while using it with an association
      # if the latter was assigned but not valid. If you want to ensure that
      # it is both present and valid, you also need to use
      # {validates_associated}[rdoc-ref:Validations::ClassMethods#validates_associated].
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
      #   See ActiveModel::Validation#validates! for more information.
      def validates_presence_of(*attr_names)
        validates_with PresenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
