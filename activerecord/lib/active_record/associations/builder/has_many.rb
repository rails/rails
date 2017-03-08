require 'active_support/core_ext/object/inclusion'

module ActiveRecord::Associations::Builder
  class HasMany < CollectionAssociation #:nodoc:
    self.macro = :has_many

    self.valid_options += [:primary_key, :dependent, :as, :through, :source, :source_type, :inverse_of]

    def build
      reflection = super
      configure_dependency
      reflection
    end

    private

      def configure_dependency
        if options[:dependent]
          unless options[:dependent].in?([:destroy, :delete_all, :nullify, :restrict])
            raise ArgumentError, "The :dependent option expects either :destroy, :delete_all, " \
                                 ":nullify or :restrict (#{options[:dependent].inspect})"
          end

          send("define_#{options[:dependent]}_dependency_method")
          model.before_destroy dependency_method_name
        end
      end

      def define_destroy_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          send(name).each do |o|
            # No point in executing the counter update since we're going to destroy the parent anyway
            counter_method = ('belongs_to_counter_cache_before_destroy_for_' + self.class.name.downcase).to_sym
            if o.respond_to?(counter_method)
              class << o
                self
              end.send(:define_method, counter_method, Proc.new {})
            end
          end

          send(name).delete_all
        end
      end

      def define_delete_all_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          association(name).delete_all_on_destroy
        end
      end

      def define_nullify_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          send(name).delete_all
        end
      end

      def define_restrict_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          if send(name).exists?
            msg = "has_many association :dependent => :restrict option, no longer raises an " \
                  "ActiveRecord::DeleteRestrictionError and is going to be deprecated in the " \
                  "next version. In order for the exception be raised, please set " \
                  "ActiveRecord::Base.dependent_restrict_raises = true."

            ActiveSupport::Deprecation.warn msg

            if dependent_restrict_raises == true
              raise ActiveRecord::DeleteRestrictionError.new(name)
            else
              self.errors.add(:base, "Cannot delete record because dependent #{name} exist")
              return false
            end
          end
        end
      end

      def dependency_method_name
        "has_many_dependent_for_#{name}"
      end
  end
end
