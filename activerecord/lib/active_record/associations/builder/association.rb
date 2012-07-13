module ActiveRecord::Associations::Builder
  class Association #:nodoc:
    class << self
      attr_accessor :valid_options
    end

    self.valid_options = [:class_name, :foreign_key, :select, :conditions, :include, :extend, :readonly, :validate, :references]

    attr_reader :model, :name, :scope, :options, :reflection

    def self.build(*args, &block)
      new(*args, &block).build
    end

    def initialize(model, name, scope, options)
      @model   = model
      @name    = name

      if options
        @scope   = scope
        @options = options
      else
        @scope   = nil
        @options = scope
      end
    end

    def mixin
      @model.generated_feature_methods
    end

    include Module.new { def build; end }

    def build
      validate_options
      define_accessors
      @reflection = model.create_reflection(macro, name, scope, options, model)
      super # provides an extension point
      @reflection
    end

    def macro
      raise NotImplementedError
    end

    def valid_options
      Association.valid_options
    end

    private

      def validate_options
        options.assert_valid_keys(valid_options)
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
          has_one_macro = association(name).reflection.macro == :has_one
          if has_one_macro ? !send(name).nil? : send(name).exists?
            if dependent_restrict_raises?
              raise ActiveRecord::DeleteRestrictionError.new(name)
            else
              key  = has_one_macro ? "one" : "many"
              errors.add(:base, :"restrict_dependent_destroy.#{key}",
                         :record => self.class.human_attribute_name(name).downcase)
              return false
            end
          end
        end
      end
  end
end
