
module ActiveRecord::Associations::Builder
  class HasMany < CollectionAssociation #:nodoc:
    def macro
      :has_many
    end

    def valid_options
      super + [:primary_key, :dependent, :as, :through, :source, :source_type, :inverse_of]
    end

    def build
      reflection = super
      configure_dependency
      reflection
    end

    def configure_dependency
      if dependent = options[:dependent]
        validate_dependent_option [:destroy, :delete_all, :nullify, :restrict, :restrict_with_error, :restrict_with_exception]

        name = self.name
        mixin.redefine_method(dependency_method_name) do
          association(name).handle_dependency
        end

        model.before_destroy dependency_method_name
      end
    end

    def dependency_method_name
      "has_many_dependent_for_#{name}"
    end
  end
end
