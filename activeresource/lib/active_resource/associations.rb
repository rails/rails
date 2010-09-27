module ActiveResource
  module Associations

    def hash_options(association, resource)
      h = { :klass => klass_for(association, resource) }
      h[:host_klass]      = self
      case association
        when :has_many
        h[:association_col] = "#{h[:host_klass].to_s.downcase}_id".to_sym

        when :has_one
        h[:association_col] = "#{h[:host_klass].to_s.underscore}_id".to_sym
      end
      h
    end

    def klass_for(association, resource)
      resource = resource.to_s
      resource = resource.singularize if association == :has_many
      resource.camelize.constantize
    end

    def has_one(resource, opts = {})
      h  = hash_options(:has_one, resource)
      klass_name = opts[:class_name].nil? ? resource : opts[:class_name]

      #----------------------------------------------------------------------#
      # Define accessor method for resource
      #
      #----------------------------------------------------------------------#
      define_method(klass_name) do
        if instance_variable_get("@#{resource}").nil?
          instance_variable_set("@#{resource}",
                                h[:klass].find(:first, :params => { h[:association_col] => id }) )
        end
        return instance_variable_get("@#{resource}")
      end
    end

  end
end
