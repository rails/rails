# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class HasMany < CollectionAssociation # :nodoc:
    register_builder_for :has_many

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

    private_class_method :valid_options, :valid_dependent_options
  end
end
