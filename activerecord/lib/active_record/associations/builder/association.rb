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
#      - HasAndBelongsToManyAssociation

module ActiveRecord::Associations::Builder
  class Association #:nodoc:
    class << self
      attr_accessor :valid_options
      attr_accessor :extensions
    end

    self.valid_options = [:class_name, :foreign_key, :validate]
    self.extensions    = []

    attr_reader :model, :name, :scope, :options

    def self.build(*args, &block)
      new(*args, &block).build
    end

    def initialize(model, name, scope, options)
      raise ArgumentError, "association names must be a Symbol" unless name.kind_of?(Symbol)

      @model   = model
      @name    = name

      if scope.is_a?(Hash)
        @scope   = nil
        @options = scope
      else
        @scope   = scope
        @options = options
      end

      if @scope && @scope.arity == 0
        prev_scope = @scope
        @scope = proc { instance_exec(&prev_scope) }
      end
    end

    def mixin
      @model.generated_feature_methods
    end

    def build
      validate_options
      define_accessors
      configure_dependency if options[:dependent]
      reflection = ActiveRecord::Reflection.create(macro, name, scope, options, model)
      Association.extensions.each do |extension|
        extension.build @model, reflection
      end
      reflection
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

    # Defines the setter and getter methods for the association
    # class Post < ActiveRecord::Base
    #   has_many :comments
    # end
    #
    # Post.first.comments and Post.first.comments= methods are defined by this method...

    def define_accessors
      define_readers
      define_writers
    end

    def define_readers
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}(*args)
          association(:#{name}).reader(*args)
        end
      CODE
    end

    def define_writers
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}=(value)
          association(:#{name}).writer(value)
        end
      CODE
    end

    def configure_dependency
      unless valid_dependent_options.include? options[:dependent]
        raise ArgumentError, "The :dependent option must be one of #{valid_dependent_options}, but is :#{options[:dependent]}"
      end

      n = name
      model.before_destroy lambda { |o| o.association(n).handle_dependency }
    end

    def valid_dependent_options
      raise NotImplementedError
    end
  end
end
