# This is the parent Association class which defines the variables
# used by all associations.
#
# The hierarchy is defined as follows:
#  Association
#    - SingularAssociation
#      - BelongsToAssociation
#      - HasOneAssociation
#    - CollectionAssociation
#      - HasManyAssociation

module ActiveRecord::Associations::Builder
  class Association #:nodoc:
    class << self
      attr_accessor :extensions
    end
    self.extensions = []

    VALID_OPTIONS = [:class_name, :class, :foreign_key, :validate]

    attr_reader :name, :scope, :options

    def self.build(model, name, scope, options, &block)
      builder = create_builder model, name, scope, options, &block
      reflection = builder.build(model)
      builder.define_accessors model, reflection
      define_callbacks model, reflection
      builder.define_extensions model
      reflection
    end

    def self.create_builder(model, name, scope, options, &block)
      raise ArgumentError, "association names must be a Symbol" unless name.kind_of?(Symbol)

      if scope.is_a?(Hash)
        options = scope
        scope   = nil
      end

      new(name, scope, options, &block)
    end

    def initialize(name, scope, options)
      @name    = name
      @scope   = scope
      @options = options

      validate_options

      if scope && scope.arity == 0
        @scope = proc { instance_exec(&scope) }
      end
    end

    def build(model)
      ActiveRecord::Reflection.create(macro, name, scope, options, model)
    end

    def macro
      raise NotImplementedError
    end

    def valid_options
      VALID_OPTIONS + Association.extensions.flat_map(&:valid_options)
    end

    def validate_options
      options.assert_valid_keys(valid_options)
    end

    def define_extensions(model)
    end

    def self.define_callbacks(model, reflection)
      add_before_destroy_callbacks(model, reflection) if reflection.options[:dependent]
      Association.extensions.each do |extension|
        extension.build model, reflection
      end
    end

    # Defines the setter and getter methods for the association
    # class Post < ActiveRecord::Base
    #   has_many :comments
    # end
    #
    # Post.first.comments and Post.first.comments= methods are defined by this method...

    def define_accessors(model, reflection)
      mixin = model.generated_feature_methods
      define_readers(mixin)
      define_writers(mixin)
    end

    def define_readers(mixin)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}(*args)
          association(:#{name}).reader(*args)
        end
      CODE
    end

    def define_writers(mixin)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}=(value)
          association(:#{name}).writer(value)
        end
      CODE
    end

    def self.valid_dependent_options
      raise NotImplementedError
    end

    private

    def self.add_before_destroy_callbacks(model, reflection)
      unless valid_dependent_options.include? reflection.options[:dependent]
        raise ArgumentError, "The :dependent option must be one of #{valid_dependent_options}, but is :#{reflection.options[:dependent]}"
      end

      name = reflection.name
      model.before_destroy lambda { |o| o.association(name).handle_dependency }
    end
  end
end
