module ActiveModel
  module Validations
    module HelperMethods
      private

        def _merge_attributes(attr_names)
          options = attr_names.extract_options!
          options.merge(:attributes => attr_names.flatten)
        end
    end
  end
end