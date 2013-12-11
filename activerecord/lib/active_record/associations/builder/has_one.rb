module ActiveRecord::Associations::Builder
  class HasOne < SingularAssociation #:nodoc:
    def self.macro
      :has_one
    end

    def self.valid_options(options)
      valid = super + [:as, :foreign_type]
      valid += [:through, :source, :source_type] if options[:through]
      valid
    end

    def self.valid_dependent_options
      [:destroy, :delete, :nullify, :restrict_with_error, :restrict_with_exception]
    end

    def self.add_destroy_callbacks(model, reflection)
      super unless reflection.options[:through]
    end
  end
end
