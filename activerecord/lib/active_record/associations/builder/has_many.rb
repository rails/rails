
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

    private

      def configure_dependency
        if dependent = options[:dependent]
          validate_dependent_option [:destroy, :delete_all, :nullify, :restrict, :restrict_with_error, :restrict_with_exception]
          send("define_#{dependent}_dependency_method")
          model.before_destroy dependency_method_name
        end
      end

      def define_destroy_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          send(name).each do |o|
            # No point in executing the counter update since we're going to destroy the parent anyway
            o.mark_for_destruction
          end

          send(name).delete_all
        end
      end

      def define_delete_all_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          association(name).delete_all
        end
      end

      def define_nullify_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          send(name).delete_all
        end
      end

      def dependency_method_name
        "has_many_dependent_for_#{name}"
      end
  end
end
