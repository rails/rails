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

    def configure_dependency
      super unless options[:through]
    end

    def valid_dependent_options
      [:destroy, :delete, :nullify, :restrict, :restrict_with_error, :restrict_with_exception]
    end
  end
end
