# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class BelongsTo < SingularAssociation # :nodoc:
    def self.macro
      :belongs_to
    end

    def self.valid_options(options)
      valid = super + [:polymorphic, :counter_cache, :optional, :default]
      valid << :class_name unless options[:polymorphic]
      valid << :foreign_type if options[:polymorphic]
      valid << :ensuring_owner_was if options[:dependent] == :destroy_async
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

        if association.saved_change_to_target?
          association.increment_counters
          association.decrement_counters_before_last_save
        end
      }

      klass = reflection.class_name.safe_constantize
      klass._counter_cache_columns |= [cache_column] if klass && klass.respond_to?(:_counter_cache_columns)
      model.counter_cached_association_names |= [reflection.name]
    end

    def self.touch_record(o, changes, foreign_key, name, touch) # :nodoc:
      old_foreign_id = changes[foreign_key] && changes[foreign_key].first

      if old_foreign_id
        association = o.association(name)
        reflection = association.reflection
        if reflection.polymorphic?
          foreign_type = reflection.foreign_type
          klass = changes[foreign_type] && changes[foreign_type].first || o.public_send(foreign_type)
          klass = o.class.polymorphic_class_for(klass)
        else
          klass = association.klass
        end
        primary_key = reflection.association_primary_key(klass)
        old_record = klass.find_by(primary_key => old_foreign_id)

        if old_record
          if touch != true
            old_record.touch_later(touch)
          else
            old_record.touch_later
          end
        end
      end

      record = o.public_send name
      if record && record.persisted?
        if touch != true
          record.touch_later(touch)
        else
          record.touch_later
        end
      end
    end

    def self.add_touch_callbacks(model, reflection)
      foreign_key = reflection.foreign_key
      name        = reflection.name
      touch       = reflection.options[:touch]

      callback = lambda { |changes_method| lambda { |record|
        BelongsTo.touch_record(record, record.send(changes_method), foreign_key, name, touch)
      }}

      if reflection.counter_cache_column
        touch_callback = callback.(:saved_changes)
        update_callback = lambda { |record|
          instance_exec(record, &touch_callback) unless association(reflection.name).saved_change_to_target?
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
      if reflection.deprecated?
        # If :dependent is set, destroying the record has some side effect that
        # would no longer happen if the association is removed.
        model.before_destroy do
          report_deprecated_association(reflection, context: ":dependent has a side effect here")
        end
      end

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
        if ActiveRecord.belongs_to_required_validates_foreign_key
          model.validates_presence_of reflection.name, message: :required
        else
          condition = lambda { |record|
            foreign_key = reflection.foreign_key
            foreign_type = reflection.foreign_type

            record.read_attribute(foreign_key).nil? ||
              record.attribute_changed?(foreign_key) ||
              (reflection.polymorphic? && (record.read_attribute(foreign_type).nil? || record.attribute_changed?(foreign_type)))
          }

          model.validates_presence_of reflection.name, message: :required, if: condition
        end
      end
    end

    def self.define_change_tracking_methods(model, reflection)
      model.generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{reflection.name}_changed?
          association = association(:#{reflection.name})
          deprecated_associations_api_guard(association, __method__)
          association.target_changed?
        end

        def #{reflection.name}_previously_changed?
          association = association(:#{reflection.name})
          deprecated_associations_api_guard(association, __method__)
          association.target_previously_changed?
        end
      CODE
    end

    private_class_method :macro, :valid_options, :valid_dependent_options, :define_callbacks,
      :define_validations, :define_change_tracking_methods, :add_counter_cache_callbacks,
      :add_touch_callbacks, :add_default_callbacks, :add_destroy_callbacks
  end
end
