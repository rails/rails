module ActionController
  module ModelNaming
    # Converts the given object to an ActiveModel compliant one.
    def convert_to_model(object)
      object.respond_to?(:to_model) ? object.to_model : object
    end

    def model_name_from_record_or_class(record_or_class)
      convert_to_model(record_or_class).model_name
    end
  end
end
