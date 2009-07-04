require 'active_support/core_ext/object/instance_variables'

module ActiveModel
  module Attributes
    def self.append_features(base)
      unless base.instance_methods.include?('attributes')
        super
      else
        false
      end
    end

    def attributes
      instance_values
    end

    def read_attribute(attr_name)
      instance_variable_get(:"@#{attr_name}")
    end

    def write_attribute(attr_name, value)
      instance_variable_set(:"@#{attr_name}", value)
    end
  end
end
