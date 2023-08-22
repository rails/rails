# frozen_string_literal: true

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
  class Association # :nodoc:
    class << self
      attr_accessor :extensions
    end
    self.extensions = []

    VALID_OPTIONS = [
      :class_name, :anonymous_class, :primary_key, :foreign_key, :dependent, :validate, :inverse_of, :strict_loading, :query_constraints
    ].freeze # :nodoc:

    def self.build(model, name, scope, options, &block)
      if model.dangerous_attribute_method?(name)
        raise ArgumentError, "You tried to define an association named #{name} on the model #{model.name}, but " \
                             "this will conflict with a method #{name} already defined by Active Record. " \
                             "Please choose a different association name."
      end

      reflection = create_reflection(model, name, scope, options, &block)
      define_accessors model, reflection
      define_callbacks model, reflection
      define_validations model, reflection
      define_change_tracking_methods model, reflection
      reflection
    end

    def self.create_reflection(model, name, scope, options, &block)
      raise ArgumentError, "association names must be a Symbol" unless name.kind_of?(Symbol)

      validate_options(options)

      extension = define_extensions(model, name, &block)
      options[:extend] = [*options[:extend], extension] if extension

      scope = build_scope(scope)

      ActiveRecord::Reflection.create(macro, name, scope, options, model)
    end

    def self.build_scope(scope)
      if scope && scope.arity == 0
        proc { instance_exec(&scope) }
      else
        scope
      end
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
        check_dependent_options(dependent, model)
        add_destroy_callbacks(model, reflection)
        add_after_commit_jobs_callback(model, dependent)
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
        def #{name}
          association(:#{name}).reader
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

    def self.define_change_tracking_methods(model, reflection)
      # noop
    end

    def self.valid_dependent_options
      raise NotImplementedError
    end

    def self.check_dependent_options(dependent, model)
      if dependent == :destroy_async && !model.destroy_association_async_job
        err_message = "A valid destroy_association_async_job is required to use `dependent: :destroy_async` on associations"
        raise ActiveRecord::ConfigurationError, err_message
      end
      unless valid_dependent_options.include? dependent
        raise ArgumentError, "The :dependent option must be one of #{valid_dependent_options}, but is :#{dependent}"
      end
    end

    def self.add_destroy_callbacks(model, reflection)
      name = reflection.name
      model.before_destroy(->(o) { o.association(name).handle_dependency })
    end

    def self.add_after_commit_jobs_callback(model, dependent)
      if dependent == :destroy_async
        mixin = model.generated_association_methods

        unless mixin.method_defined?(:_after_commit_jobs)
          model.after_commit(-> do
            _after_commit_jobs.each do |job_class, job_arguments|
              job_class.perform_later(**job_arguments)
            end
          end)

          mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
            def _after_commit_jobs
              @_after_commit_jobs ||= []
            end
          CODE
        end
      end
    end

    private_class_method :build_scope, :macro, :valid_options, :validate_options, :define_extensions,
      :define_callbacks, :define_accessors, :define_readers, :define_writers, :define_validations,
      :define_change_tracking_methods, :valid_dependent_options, :check_dependent_options,
      :add_destroy_callbacks, :add_after_commit_jobs_callback
  end
end
