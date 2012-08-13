module ActiveModel
  class ForbiddenAttributesError < StandardError
  end

  module ForbiddenAttributesProtection
    def sanitize_for_mass_assignment(attributes, options = {})
      if attributes.respond_to?(:permitted?) && !attributes.permitted?
        raise ActiveModel::ForbiddenAttributesError
      else
        attributes
      end
    end
  end
end
