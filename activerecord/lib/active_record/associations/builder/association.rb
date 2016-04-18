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

module ActiveRecord::Associations::Builder # :nodoc:
  class Association #:nodoc:
    class << self
      attr_accessor :extensions
    end
    self.extensions = []

    VALID_OPTIONS = [:class_name, :anonymous_class, :foreign_key, :validate] # :nodoc:

    def self.build(model, name, scope, options, &block)
      if model.dangerous_attribute_method?(name)
        raise ArgumentError, "You tried to define an association named #{name} on the model #{model.name}, but " \
                             "this will conflict with a method #{name} already defined by Active Record. " \
                             "Please choose a different association name."
      end

      extension = define_extensions model, name, &block
      reflection = create_reflection model, name, scope, options, extension
      define_accessors model, reflection
      define_callbacks model, reflection
      define_validations model, reflection
      reflection
    end

    def self.create_reflection(model, name, scope, options, extension = nil)
      raise ArgumentError, "association names must be a Symbol" unless name.kind_of?(Symbol)

      if scope.is_a?(Hash)
        options = scope
        scope   = nil
      end

      validate_options(options)

      scope = build_scope(scope, extension)

      ActiveRecord::Reflection.create(macro, name, scope, options, model)
    end

    def self.build_scope(scope, extension)
      new_scope = scope

      if scope && scope.arity == 0
        new_scope = proc { instance_exec(&scope) }
      end

      if extension
        new_scope = wrap_scope new_scope, extension
      end

      new_scope
    end

    def self.wrap_scope(scope, extension)
      scope
    end

    def self.macro
      raise NotImplementedError
    end

    def self.valid_options(options)
      VALID_OPTIONS + Association.extensions.flat_map(&:valid_options)
    end

    def self.validate_options(options)
      options.assert_valid_keys(valid_options(options))
    end

    def self.define_extensions(model, name)
    end

    def self.define_callbacks(model, reflection)
      if dependent = reflection.options[:dependent]
        check_dependent_options(dependent)
        add_destroy_callbacks(model, reflection)
      end

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

    def self.define_validations(model, reflection)
      # noop
    end

    def self.valid_dependent_options
      raise NotImplementedError
    end

    def self.check_dependent_options(dependent)
      unless valid_dependent_options.include? dependent
        raise ArgumentError, "The :dependent option must be one of #{valid_dependent_options}, but is :#{dependent}"
      end
    end

    def self.add_destroy_callbacks(model, reflection)
      name = reflection.name
      model.before_destroy lambda { |o| o.association(name).handle_dependency }
    end
  end
end
