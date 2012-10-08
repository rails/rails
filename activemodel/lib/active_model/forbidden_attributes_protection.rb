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
    protected
      def sanitize_for_mass_assignment(attributes, options = {})
        if attributes.respond_to?(:permitted?) && !attributes.permitted?
          raise ActiveModel::ForbiddenAttributesError
        else
          attributes
        end
      end
  end
end
