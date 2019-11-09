# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class HasMany < CollectionAssociation #:nodoc:
    def self.macro
      :has_many
    end

    def self.valid_options(options)
      valid = super + [:primary_key, :dependent, :as, :inverse_of, :counter_cache, :join_table, :foreign_type, :index_errors]
      valid += [:through, :source, :source_type] if options[:through]
      valid
    end

    def self.valid_dependent_options
      [:destroy, :delete_all, :nullify, :restrict_with_error, :restrict_with_exception]
    end

    private_class_method :macro, :valid_options, :valid_dependent_options
  end
end
