# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class HasOne < SingularAssociation # :nodoc:
    register_builder_for :has_one

    def self.valid_options(options)
      valid = super + [:as, :through]
      valid += [:foreign_type] if options[:as]
      valid += [:ensuring_owner_was] if options[:dependent] == :destroy_async
      valid += [:source, :source_type, :disable_joins] if options[:through]
      valid
    end

    def self.valid_dependent_options
      [:destroy, :destroy_async, :delete, :nullify, :restrict_with_error, :restrict_with_exception]
    end

    def self.define_callbacks(model, reflection)
      super
      add_touch_callbacks(model, reflection) if reflection.options[:touch]
    end

    def self.add_destroy_callbacks(model, reflection)
      super unless reflection.options[:through]
    end

    def self.define_validations(model, reflection)
      super
      if reflection.options[:required]
        model.validates_presence_of reflection.name, message: :required
      end
    end

    def self.touch_record(record, name, touch)
      instance = record.send(name)

      if instance&.persisted?
        touch != true ?
          instance.touch(touch) : instance.touch
      end
    end

    def self.add_touch_callbacks(model, reflection)
      name  = reflection.name
      touch = reflection.options[:touch]

      callback = -> (record) { HasOne.touch_record(record, name, touch) }
      model.after_create callback, if: :saved_changes?
      model.after_create_commit { association(name).reset_negative_cache }
      model.after_update callback, if: :saved_changes?
      model.after_destroy callback
      model.after_touch callback
    end

    private_class_method :macro, :valid_options, :valid_dependent_options, :add_destroy_callbacks,
      :define_callbacks, :define_validations, :add_touch_callbacks
  end
end
