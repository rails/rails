# This class is inherited by the has_one and belongs_to association classes

module ActiveRecord::Associations::Builder
  class SingularAssociation < Association #:nodoc:
    def valid_options
      super + [:dependent, :primary_key, :inverse_of, :required]
    end

    def self.define_accessors(model, reflection)
      super
      define_constructors(model.generated_association_methods, reflection.name) if reflection.constructable?
    end

    # Defines the (build|create)_association methods for belongs_to or has_one association
    def self.define_constructors(mixin, name)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def build_#{name}(*args, &block)
          association(:#{name}).build(*args, &block)
        end

        def create_#{name}(*args, &block)
          association(:#{name}).create(*args, &block)
        end

        def create_#{name}!(*args, &block)
          association(:#{name}).create!(*args, &block)
        end
      CODE
    end

    def self.define_validations(model, reflection)
      super
      if reflection.options[:required]
        model.validates_presence_of reflection.name
      end
    end
  end
end
