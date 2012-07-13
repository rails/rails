require 'active_support/core_ext/object/inclusion'

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

    private

      def configure_dependency
        if options[:dependent]
          unless options[:dependent].in?([:destroy, :delete, :nullify, :restrict])
            raise ArgumentError, "The :dependent option expects either :destroy, :delete, " \
                                 ":nullify or :restrict (#{options[:dependent].inspect})"
          end

          dependent_restrict_deprecation_warning if options[:dependent] == :restrict
          send("define_#{options[:dependent]}_dependency_method")
          model.before_destroy dependency_method_name
        end
      end

      def define_destroy_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          association(name).delete
        end
      end
      alias :define_delete_dependency_method :define_destroy_dependency_method
      alias :define_nullify_dependency_method :define_destroy_dependency_method

      def dependency_method_name
        "has_one_dependent_#{options[:dependent]}_for_#{name}"
      end
  end
end
