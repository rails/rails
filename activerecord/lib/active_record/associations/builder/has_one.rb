# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class HasOne < SingularAssociation #:nodoc:
    def self.macro
      :has_one
    end

    def self.valid_options(options)
      valid = super + [:as, :touch]
      valid += [:through, :source, :source_type] if options[:through]
      valid
    end

    def self.define_callbacks(model, reflection)
      super

      add_touch_callbacks(model, reflection) if reflection.options[:touch]
    end

    def self.valid_dependent_options
      [:destroy, :delete, :nullify, :restrict_with_error, :restrict_with_exception]
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

    def self.touch_record(o, name, touch, touch_method) # :nodoc:
      record = o.send name

      return unless record && record.persisted?

      if touch != true
        record.send(touch_method, touch)
      else
        record.send(touch_method)
      end
    end

    def self.add_touch_callbacks(model, reflection)
      name  = reflection.name
      touch = reflection.options[:touch]

      callback = lambda { |record|
        HasOne.touch_record(record, name, touch, :touch)
      }

      model.after_create callback, if: :saved_changes?
      model.after_update callback, if: :saved_changes?
      model.after_destroy callback
      model.after_touch callback
    end
    private_class_method :macro, :valid_options, :valid_dependent_options, :add_destroy_callbacks, :define_validations,
                         :add_touch_callbacks
  end
end
