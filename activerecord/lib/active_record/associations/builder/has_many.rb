# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class HasMany < CollectionAssociation # :nodoc:
    def self.macro
      :has_many
    end

    def self.valid_options(options)
      valid = super + [:counter_cache, :join_table, :index_errors]
      valid += [:as, :foreign_type] if options[:as]
      valid += [:through, :source, :source_type] if options[:through]
      valid += [:ensuring_owner_was] if options[:dependent] == :destroy_async
      valid += [:disable_joins] if options[:disable_joins] && options[:through]
      valid
    end

    def self.valid_dependent_options
      [:destroy, :delete_all, :nullify, :restrict_with_error, :restrict_with_exception, :destroy_async]
    end

    private_class_method :macro, :valid_options, :valid_dependent_options
  end
end
