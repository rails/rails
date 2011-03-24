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

        model.redefine_method("build_#{name}") do |*params|
          association(name).build(*params)
        end

        model.redefine_method("create_#{name}") do |*params|
          association(name).create(*params)
        end

        model.redefine_method("create_#{name}!") do |*params|
          association(name).create!(*params)
        end
      end
  end
end
