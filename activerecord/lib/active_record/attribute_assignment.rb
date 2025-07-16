# frozen_string_literal: true

module ActiveRecord
  module AttributeAssignment
    # Allows you to set all the attributes by passing in a hash of attributes with
    # keys matching the attribute names.
    #
    # If the passed hash responds to <tt>permitted?</tt> method and the return value
    # of this method is +false+ an ActiveModel::ForbiddenAttributesError
    # exception is raised.
    #
    #   class Cat < ApplicationRecord
    #   end
    #
    #   cat = Cat.new
    #   cat.assign_attributes(name: "Gorby", status: "yawning")
    #   cat.name # => "Gorby"
    #   cat.status # => "yawning"
    #   cat.assign_attributes(status: "sleeping")
    #   cat.name # => "Gorby"
    #   cat.status # => "sleeping"
    def assign_attributes(attributes)
      super
    rescue ActiveModel::MultiparameterAssignmentErrors => error
      errors = error.errors.map do |error|
        ActiveRecord::AttributeAssignmentError.new(error.message, error.exception, error.attribute)
      end
      raise ActiveRecord::MultiparameterAssignmentErrors.new(errors)
    end

    alias_method :attributes=, :assign_attributes
  end
end
