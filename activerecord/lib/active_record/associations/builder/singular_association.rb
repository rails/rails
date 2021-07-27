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

      define_constructors(mixin, name) unless reflection.polymorphic?

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def reload_#{name}
          association(:#{name}).force_reload_reader
        end
      CODE

      if reflection.polymorphic? && reflection.options[:types].present?
        define_aliases(mixin, reflection)
      end
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

    # Defines aliases for belongs_to polymorphic associations
    def self.define_aliases(mixin, reflection)
      types            = reflection.options[:types]
      association_name = reflection.name

      types.each do |type|
        name = type.tableize.tr("/", "_").singularize
        type = type.inspect

        mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{name}
            if #{type} == self["#{association_name}_type"]
              association(:#{association_name}).reader
            end
          end

          def #{name}=(value)
            if #{type} == self["#{association_name}_type"]
              association(:#{association_name}).writer(value)
            end
          end

          def reload_#{name}
            if #{type} == self["#{association_name}_type"]
              association(:#{association_name}).force_reload_reader
            end
          end
        CODE
      end
    end

    private_class_method :valid_options, :define_accessors, :define_constructors, :define_aliases
  end
end
