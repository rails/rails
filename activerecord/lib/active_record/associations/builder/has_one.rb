
module ActiveRecord::Associations::Builder
  class HasOne < SingularAssociation #:nodoc:
    def macro
      :has_one
    end

    def valid_options
      valid = super + [:order, :as]
      valid += [:through, :source, :source_type] if options[:through]
      valid
    end

    def constructable?
      !options[:through]
    end

    def build
      reflection = super
      configure_dependency unless options[:through]
      reflection
    end

    def configure_dependency
      if dependent = options[:dependent]
        validate_dependent_option [:destroy, :delete, :nullify, :restrict, :restrict_with_error, :restrict_with_exception]

        name = self.name
        mixin.redefine_method(dependency_method_name) do
          association(name).handle_dependency
        end

        model.before_destroy dependency_method_name
      end
    end

    def dependency_method_name
      "has_one_dependent_for_#{name}"
    end
  end
end
