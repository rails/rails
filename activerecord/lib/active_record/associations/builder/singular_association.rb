# frozen_string_literal: true

# This class is inherited by the has_one and belongs_to association classes

module ActiveRecord::Associations::Builder # :nodoc:
  class SingularAssociation < Association # :nodoc:
    def self.valid_options(options)
      super + [:required, :touch]
    end

    def self.define_accessors(model, reflection, as:)
      super
      mixin = model.generated_association_methods
      name = reflection.name

      define_constructors(mixin, name, as: as) unless reflection.polymorphic?

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def reload_#{as}
          association(:#{name}).force_reload_reader
        end

        def reset_#{as}
          association(:#{name}).reset
        end
      CODE
    end

    # Defines the (build|create)_association methods for belongs_to or has_one association
    def self.define_constructors(mixin, name, as:)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def build_#{as}(*args, &block)
          association(:#{name}).build(*args, &block)
        end

        def create_#{as}(*args, &block)
          association(:#{name}).create(*args, &block)
        end

        def create_#{as}!(*args, &block)
          association(:#{name}).create!(*args, &block)
        end
      CODE
    end

    private_class_method :valid_options, :define_accessors, :define_constructors
  end
end
