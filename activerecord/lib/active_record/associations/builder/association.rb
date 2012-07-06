module ActiveRecord::Associations::Builder
  class Association #:nodoc:
    class_attribute :valid_options
    self.valid_options = [:class_name, :foreign_key, :select, :conditions, :include, :extend, :readonly, :validate, :references]

    # Set by subclasses
    class_attribute :macro

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

        convert_deprecated_options_to_scope!
      end
    end

    # FIXME: references should not be in this list
    DEPRECATED_OPTIONS = [:readonly, :references, :order, :limit, :joins, :group, :having,
                          :offset, :select, :uniq, :include, :conditions]

    class DeprecatedOptionsProc
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def to_proc
        options = self.options
        proc do |owner|
          if options[:where].respond_to?(:to_proc)
            context = owner || self
            where(context.instance_eval(&options[:where]))
              .merge!(options.except(:where))
          else
            scoped(options)
          end
        end
      end

      def arity
        1
      end
    end

    def convert_deprecated_options_to_scope!
      deprecated_options = options.slice(*DEPRECATED_OPTIONS)

      unless deprecated_options.empty?
        deprecated_options[:includes] = deprecated_options.delete(:include)    if deprecated_options[:include]
        deprecated_options[:where]    = deprecated_options.delete(:conditions) if deprecated_options[:conditions]

        @scope   = DeprecatedOptionsProc.new(deprecated_options)
        @options = options.except(*DEPRECATED_OPTIONS)
      end
    end

    def mixin
      @model.generated_feature_methods
    end

    def build
      validate_options
      reflection = model.create_reflection(self.class.macro, name, scope, options, model)
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
