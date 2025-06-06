# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class HasMany < CollectionAssociation # :nodoc:
    def self.macro
      :has_many
    end

    def self.valid_options(options)
      valid = super + [:counter_cache, :join_table, :index_errors, :as, :through]
      valid += [:foreign_type] if options[:as]
      valid += [:source, :source_type, :disable_joins] if options[:through]
      valid += [:ensuring_owner_was] if options[:dependent] == :destroy_async
      valid
    end

    def self.valid_dependent_options
      [:destroy, :delete_all, :nullify, :restrict_with_error, :restrict_with_exception, :destroy_async]
    end

    def self.define_change_tracking_methods(model, reflection)
      model.generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{reflection.name}_added_records
          association(:#{reflection.name}).target_added_records
        end

        def #{reflection.name}_previously_added_records
          association(:#{reflection.name}).target_previously_added_records
        end
      CODE
    end

    private_class_method :macro, :valid_options, :valid_dependent_options, :define_change_tracking_methods
  end
end
