require 'active_support/core_ext/object/inclusion'

module ActiveRecord::Associations::Builder
  class HasOne < SingularAssociation #:nodoc:
    self.macro = :has_one

    self.valid_options += [:order, :as]

    class_attribute :through_options
    self.through_options = [:through, :source, :source_type]

    def constructable?
      !options[:through]
    end

    def build
      reflection = super
      configure_dependency unless options[:through]
      reflection
    end

    private

      def validate_options
        valid_options = self.class.valid_options
        valid_options += self.class.through_options if options[:through]
        options.assert_valid_keys(valid_options)
      end

      def configure_dependency
        if options[:dependent]
          unless options[:dependent].in?([:destroy, :delete, :nullify, :restrict])
            raise ArgumentError, "The :dependent option expects either :destroy, :delete, " \
                                 ":nullify or :restrict (#{options[:dependent].inspect})"
          end

          send("define_#{options[:dependent]}_dependency_method")
          model.before_destroy dependency_method_name
        end
      end

      def dependency_method_name
        "has_one_dependent_#{options[:dependent]}_for_#{name}"
      end

      def define_destroy_dependency_method
        model.send(:class_eval, <<-eoruby, __FILE__, __LINE__ + 1)
          def #{dependency_method_name}
            association(#{name.to_sym.inspect}).delete
          end
        eoruby
      end
      alias :define_delete_dependency_method :define_destroy_dependency_method
      alias :define_nullify_dependency_method :define_destroy_dependency_method

      def define_restrict_dependency_method
        name = self.name
        model.redefine_method(dependency_method_name) do
          raise ActiveRecord::DeleteRestrictionError.new(name) unless send(name).nil?
        end
      end
  end
end
