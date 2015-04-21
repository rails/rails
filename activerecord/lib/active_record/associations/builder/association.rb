require 'active_support/core_ext/module/attribute_accessors'

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
      # TODO: This class accessor is needed to make activerecord-deprecated_finders work.
      # We can move it to a constant in 5.0.
      attr_accessor :valid_options
    end
    self.extensions = []

    self.valid_options = [:class_name, :anonymous_class, :foreign_key, :validate]

    attr_reader :name, :scope, :options

    def self.build(model, name, scope, options, &block)
      if model.dangerous_attribute_method?(name)
        raise ArgumentError, "You tried to define an association named #{name} on the model #{model.name}, but " \
                             "this will conflict with a method #{name} already defined by Active Record. " \
                             "Please choose a different association name."
      end

      builder = create_builder model, name, scope, options, &block
      reflection = builder.build(model)
      define_accessors model, reflection
      define_callbacks model, reflection
      builder.define_extensions model
      reflection
    end

    def self.create_builder(model, name, scope, options, &block)
      raise ArgumentError, "association names must be a Symbol" unless name.kind_of?(Symbol)

      new(model, name, scope, options, &block)
    end

    def initialize(model, name, scope, options)
      # TODO: Move this to create_builder as soon we drop support to activerecord-deprecated_finders.
      if scope.is_a?(Hash)
        options = scope
        scope   = nil
      end

      # TODO: Remove this model argument as soon we drop support to activerecord-deprecated_finders.
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
      Association.valid_options + Association.extensions.flat_map(&:valid_options)
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
    def self.define_accessors(model, reflection)
      mixin = model.generated_association_methods
      name = reflection.name
      define_readers(mixin, name)
      define_writers(mixin, name)
    end

    def self.define_readers(mixin, name)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}(*args)
          association(:#{name}).reader(*args)
        end
      CODE
    end

    def self.define_writers(mixin, name)
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
