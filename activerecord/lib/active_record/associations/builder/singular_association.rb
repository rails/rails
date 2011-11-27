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

      def define_constructors
        name = self.name

        mixin.redefine_method("build_#{name}") do |*params, &block|
          association(name).build(*params, &block)
        end

        mixin.redefine_method("create_#{name}") do |*params, &block|
          association(name).create(*params, &block)
        end

        mixin.redefine_method("create_#{name}!") do |*params, &block|
          association(name).create!(*params, &block)
        end
      end
  end
end
