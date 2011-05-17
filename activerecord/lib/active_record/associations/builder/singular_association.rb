module ActiveRecord::Associations::Builder
  class SingularAssociation < Association #:nodoc:
    self.valid_options += [:remote, :dependent, :counter_cache, :primary_key, :inverse_of]

    def constructable?
      true
    end

    def define_accessors
      super
      define_constructors if constructable?
    end

    private

      def define_readers
        super
        name = self.name

        model.redefine_method("#{name}_loaded?") do
          ActiveSupport::Deprecation.warn(
            "Calling obj.#{name}_loaded? is deprecated. Please use " \
            "obj.association(:#{name}).loaded? instead."
          )
          association(name).loaded?
        end
      end

      def define_constructors
        name = self.name

        model.redefine_method("build_#{name}") do |*params, &block|
          association(name).build(*params, &block)
        end

        model.redefine_method("create_#{name}") do |*params, &block|
          association(name).create(*params, &block)
        end

        model.redefine_method("create_#{name}!") do |*params, &block|
          association(name).create!(*params, &block)
        end
      end
  end
end
