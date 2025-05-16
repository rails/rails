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

      define_constructors(mixin, reflection) unless reflection.polymorphic?

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def reload_#{reflection.name}
          #{generate_code_to_guard_deprecated_access(reflection)}
          association(:#{reflection.name}).force_reload_reader
        end

        def reset_#{reflection.name}
          #{generate_code_to_guard_deprecated_access(reflection)}
          association(:#{reflection.name}).reset
        end
      CODE
    end

    # Defines the (build|create)_association methods for belongs_to or has_one association
    def self.define_constructors(mixin, reflection)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def build_#{reflection.name}(*args, &block)
          #{generate_code_to_guard_deprecated_access(reflection)}
          association(:#{reflection.name}).build(*args, &block)
        end

        def create_#{reflection.name}(*args, &block)
          #{generate_code_to_guard_deprecated_access(reflection)}
          association(:#{reflection.name}).create(*args, &block)
        end

        def create_#{reflection.name}!(*args, &block)
          #{generate_code_to_guard_deprecated_access(reflection)}
          association(:#{reflection.name}).create!(*args, &block)
        end
      CODE
    end

    def self.define_callbacks(model, reflection)
      super

      # If the record is saved or destroyed and `:touch` is set, the parent
      # record gets a timestamp updated. We want to know about it, because
      # deleting the association would change that side-effect and perhaps there
      # is code relying on it.
      if reflection.deprecated? && reflection.options[:touch]
        model.before_save do
          ActiveRecord::Associations::Deprecation.notify(reflection)
        end

        model.before_destroy do
          ActiveRecord::Associations::Deprecation.notify(reflection)
        end
      end
    end

    def self.define_validations(model, reflection)
      # noop
    end

    def self.define_change_tracking_methods(model, reflection)
      # noop
    end

    def self.valid_dependent_options
      [:destroy, :delete_all]
    end

    private_class_method :valid_dependent_options

    private_class_method :valid_options, :define_accessors, :define_constructors
  end
end
