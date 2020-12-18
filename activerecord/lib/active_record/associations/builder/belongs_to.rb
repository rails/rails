# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class BelongsTo < SingularAssociation #:nodoc:
    def self.macro
      :belongs_to
    end

    def self.valid_options(options)
      valid = super + [:polymorphic, :counter_cache, :optional, :default]
      valid += [:foreign_type] if options[:polymorphic]
      valid += [:ensuring_owner_was] if options[:dependent] == :destroy_async
      valid
    end

    def self.valid_dependent_options
      [:destroy, :delete, :destroy_async]
    end

    def self.define_callbacks(model, reflection)
      super
      add_counter_cache_callbacks(model, reflection) if reflection.options[:counter_cache]
      add_touch_callbacks(model, reflection)         if reflection.options[:touch]
      add_default_callbacks(model, reflection)       if reflection.options[:default]
    end

    def self.add_counter_cache_callbacks(model, reflection)
      cache_column = reflection.counter_cache_column

      model.after_update lambda { |record|
        association = association(reflection.name)

        if association.target_changed?
          association.increment_counters
          association.decrement_counters_before_last_save
        end
      }

      klass = reflection.class_name.safe_constantize
      klass.attr_readonly cache_column if klass && klass.respond_to?(:attr_readonly)
    end

    def self.touch_record(o, changes, foreign_key, name, touch, touch_method) # :nodoc:
      old_foreign_id = changes[foreign_key] && changes[foreign_key].first

      if old_foreign_id
        association = o.association(name)
        reflection = association.reflection
        if reflection.polymorphic?
          foreign_type = reflection.foreign_type
          klass = changes[foreign_type] && changes[foreign_type].first || o.public_send(foreign_type)
          klass = klass.constantize
        else
          klass = association.klass
        end
        primary_key = reflection.association_primary_key(klass)
        old_record = klass.find_by(primary_key => old_foreign_id)

        if old_record
          if touch != true
            old_record.public_send(touch_method, touch)
          else
            old_record.public_send(touch_method)
          end
        end
      end

      record = o.public_send name
      if record && record.persisted?
        if touch != true
          record.public_send(touch_method, touch)
        else
          record.public_send(touch_method)
        end
      end
    end

    def self.add_touch_callbacks(model, reflection)
      foreign_key = reflection.foreign_key
      name        = reflection.name
      touch       = reflection.options[:touch]

      callback = lambda { |changes_method| lambda { |record|
        BelongsTo.touch_record(record, record.send(changes_method), foreign_key, name, touch, belongs_to_touch_method)
      }}

      if reflection.counter_cache_column
        touch_callback = callback.(:saved_changes)
        update_callback = lambda { |record|
          instance_exec(record, &touch_callback) unless association(reflection.name).target_changed?
        }
        model.after_update update_callback, if: :saved_changes?
      else
        model.after_create callback.(:saved_changes), if: :saved_changes?
        model.after_update callback.(:saved_changes), if: :saved_changes?
        model.after_destroy callback.(:changes_to_save)
      end

      model.after_touch callback.(:changes_to_save)
    end

    def self.add_default_callbacks(model, reflection)
      model.before_validation lambda { |o|
        o.association(reflection.name).default(&reflection.options[:default])
      }
    end

    def self.add_destroy_callbacks(model, reflection)
      model.after_destroy lambda { |o| o.association(reflection.name).handle_dependency }
    end

    def self.define_validations(model, reflection)
      if reflection.options.key?(:required)
        reflection.options[:optional] = !reflection.options.delete(:required)
      end

      if reflection.options[:optional].nil?
        required = model.belongs_to_required_by_default
      else
        required = !reflection.options[:optional]
      end

      super

      if required
        model.validates_presence_of reflection.name, message: :required
      end
    end

    private_class_method :macro, :valid_options, :valid_dependent_options, :define_callbacks, :define_validations,
      :add_counter_cache_callbacks, :add_touch_callbacks, :add_default_callbacks, :add_destroy_callbacks
  end
end
