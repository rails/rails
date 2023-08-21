# frozen_string_literal: true

# This class is inherited by the has_one and belongs_to association classes

module ActiveRecord::Associations::Builder # :nodoc:
  class SingularAssociation < Association # :nodoc:
    def self.valid_options(options)
      super + [:required, :touch]
    end

    def self.define_accessors(model, reflection)
      super
      mixin = model.generated_association_methods
      name = reflection.name

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def reload_#{name}
          association(:#{name}).force_reload_reader
        end

        def reset_#{name}
          association(:#{name}).reset
        end
      CODE
    end

    def self.define_association_name(name)
      name
    end

    private_class_method :valid_options, :define_accessors
  end
end
