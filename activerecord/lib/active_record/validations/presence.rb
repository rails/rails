# frozen_string_literal: true

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
      # Object#blank?). If the attribute is an association, the associated object
      # is also considered blank if it is marked for destruction.
      #
      #   class Person < ActiveRecord::Base
      #     has_one :face
      #     validates_presence_of :face
      #   end
      #
      # The face attribute must be in the object and it cannot be blank or marked
      # for destruction.
      #
      # This validator defers to the Active Model validation for presence, adding the
      # check to see that an associated object is not marked for destruction. This
      # prevents the parent object from validating successfully and saving, which then
      # deletes the associated object, thus putting the parent object into an invalid
      # state.
      #
      # See ActiveModel::Validations::HelperMethods.validates_presence_of for
      # more information.
      #
      # NOTE: This validation will not fail while using it with an association
      # if the latter was assigned but not valid. If you want to ensure that
      # it is both present and valid, you also need to use
      # {validates_associated}[rdoc-ref:Validations::ClassMethods#validates_associated].
      def validates_presence_of(*attr_names)
        validates_with PresenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
