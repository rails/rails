module ActiveRecord::Associations::Builder
  class Association #:nodoc:
    class_attribute :valid_options
    self.valid_options = [:class_name, :foreign_key, :select, :conditions, :include, :extend, :readonly, :validate, :references]

    # Set by subclasses
    class_attribute :macro

    attr_reader :model, :name, :options, :reflection

    def self.build(model, name, options)
      new(model, name, options).build
    end

    def initialize(model, name, options)
      @model, @name, @options = model, name, options
    end

    def mixin
      @model.generated_feature_methods
    end

    def build
      validate_options
      reflection = model.create_reflection(self.class.macro, name, options, model)
      define_accessors
      reflection
    end

    private

      def validate_options
        options.assert_valid_keys(self.class.valid_options)
      end

      def define_accessors
        define_readers
        define_writers
      end

      def define_readers
        name = self.name
        mixin.redefine_method(name) do |*params|
          association(name).reader(*params)
        end
      end

      def define_writers
        name = self.name
        mixin.redefine_method("#{name}=") do |value|
          association(name).writer(value)
        end
      end

      def dependent_restrict_raises?
        ActiveRecord::Base.dependent_restrict_raises == true
      end

      def dependent_restrict_deprecation_warning
        if dependent_restrict_raises?
          msg = "In the next release, `:dependent => :restrict` will not raise a `DeleteRestrictionError`. "\
                "Instead, it will add an error on the model. To fix this warning, make sure your code " \
                "isn't relying on a `DeleteRestrictionError` and then add " \
                "`config.active_record.dependent_restrict_raises = false` to your application config."
          ActiveSupport::Deprecation.warn msg
        end
      end

      def define_restrict_dependency_method
        name = self.name
        mixin.redefine_method(dependency_method_name) do
          # has_many or has_one associations
          if send(name).respond_to?(:exists?) ? send(name).exists? : !send(name).nil?
            if dependent_restrict_raises?
              raise ActiveRecord::DeleteRestrictionError.new(name)
            else
              key  = association(name).reflection.macro == :has_one ? "one" : "many"
              errors.add(:base, :"restrict_dependent_destroy.#{key}",
                         :record => self.class.human_attribute_name(name).downcase)
              return false
            end
          end
        end
      end
  end
end
