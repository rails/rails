module ActiveModel
  # Raised when forbidden attributes are used for mass assignment.
  #
  #   class Person < ActiveRecord::Base
  #   end
  #
  #   params = ActionController::Parameters.new(name: 'Bob')
  #   Person.new(params)
  #   # => ActiveModel::ForbiddenAttributesError
  #
  #   params.permit!
  #   Person.new(params)
  #   # => #<Person id: nil, name: "Bob">
  class ForbiddenAttributesError < StandardError
  end

  module ForbiddenAttributesProtection # :nodoc:
    private
      def sanitize_for_mass_assignment(attributes)
        if attributes.respond_to?(:permitted?)
          raise ActiveModel::ForbiddenAttributesError if !attributes.permitted?
          attributes.to_h
        else
          attributes
        end
      end
      alias :sanitize_forbidden_attributes :sanitize_for_mass_assignment
  end
end
