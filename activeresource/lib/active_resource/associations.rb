module ActiveResource
  module Associations

    def hash_options(association, resource)
      h = { :klass => klass_for(association, resource) }
      h[:host_klass]      = self
      case association
      when :belongs_to
        h[:association_col] = "#{h[:klass].to_s.underscore}_id".to_sym
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
      #   Define accessor method for resource
      #
      #----------------------------------------------------------------------#
      define_method(klass_name) do
        if  !instance_variable_defined?("@#{resource}") ||
            instance_variable_get("@#{resource}").nil?
          instance_variable_set("@#{resource}",
                                h[:klass].find(:first, :params => { h[:association_col] => id }))
        end
        return instance_variable_get("@#{resource}")
      end

      #----------------------------------------------------------------------#
      # Define writter method for resource
      #
      #----------------------------------------------------------------------#
      define_method("#{klass_name}=") do |new_resource|
        if send(resource).blank?
          new_resource.send("#{h[:association_col]}=", id)
          instance_variable_set("@#{resource}", new_resource.save)
        else
          instance_variable_get("@#{resource}").send(:update_attribute, h[:association_col], id)
        end
      end
    end

    def belongs_to(resource, opts = {})
      h  = hash_options(:belongs_to, resource)
      klass_name = opts[:class_name].nil? ? resource : opts[:class_name]

      #----------------------------------------------------------------------#
      #   Define accessor method for resource
      #
      #----------------------------------------------------------------------#
      define_method(klass_name) do
        if  !instance_variable_defined?("@#{resource}") ||
            instance_variable_get("@#{resource}").nil?
          instance_variable_set("@#{resource}", h[:klass].find(send h[:association_col]))
        end
        return instance_variable_get("@#{resource}")
      end
    end
  end
end
