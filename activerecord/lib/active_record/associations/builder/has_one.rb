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

    def self.valid_dependent_options
      [:destroy, :delete, :nullify, :restrict_with_error, :restrict_with_exception]
    end

    private

    def self.add_before_destroy_callbacks(model, reflection)
      super unless reflection.options[:through]
    end
  end
end
