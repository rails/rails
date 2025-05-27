# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class HasMany < CollectionAssociation # :nodoc:
    def self.macro
      :has_many
    end

    def self.valid_options(options)
      valid = super + [:counter_cache, :join_table, :index_errors, :as, :through]
      valid += [:foreign_type] if options[:as]
      valid += [:source, :source_type, :disable_joins, :_parent_reflection] if options[:through]
      valid += [:ensuring_owner_was] if options[:dependent] == :destroy_async
      valid
    end

    def self.internal_options(options)
      if options[:through]
        super + [:_parent_reflection]
      else
        super
      end
    end

    def self.valid_dependent_options
      [:destroy, :delete_all, :nullify, :restrict_with_error, :restrict_with_exception, :destroy_async]
    end

    private_class_method :macro, :valid_options, :valid_dependent_options
  end
end
