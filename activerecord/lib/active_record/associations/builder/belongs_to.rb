# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class BelongsTo < SingularAssociation #:nodoc:
    def self.macro
      :belongs_to
    end

    def self.valid_options(options)
      super + [:polymorphic, :touch, :counter_cache, :optional, :default]
    end

    def self.valid_dependent_options
      [:destroy, :delete]
    end

    def self.define_callbacks(model, reflection)
      super
      add_counter_cache_callbacks(model, reflection) if reflection.options[:counter_cache]
      add_touch_callbacks(model, reflection)         if reflection.options[:touch]
      add_default_callbacks(model, reflection)       if reflection.options[:default]
    end

    def self.define_accessors(mixin, reflection)
      super
      add_counter_cache_methods mixin
    end

    def self.add_counter_cache_methods(mixin)
      return if mixin.method_defined? :belongs_to_counter_cache_after_update

      mixin.class_eval do
        def belongs_to_counter_cache_after_update(reflection)
          foreign_key  = reflection.foreign_key
          cache_column = reflection.counter_cache_column

          @_after_replace_counter_called ||= {}
          if @_after_replace_counter_called.has_key?(foreign_key)
            @_after_replace_counter_called.delete(foreign_key)
          elsif association(reflection.name).target_changed?
            if reflection.polymorphic?
              model     = attribute_in_database(reflection.foreign_type).try(:constantize)
              model_was = attribute_before_last_save(reflection.foreign_type).try(:constantize)
            else
              model     = reflection.klass
              model_was = reflection.klass
            end

            foreign_key_was = attribute_before_last_save foreign_key
            foreign_key     = attribute_in_database foreign_key

            if foreign_key && model < ActiveRecord::Base
              counter_cache_target(reflection, model, foreign_key).update_counters(cache_column => 1)
            end

            if foreign_key_was && model_was < ActiveRecord::Base
              counter_cache_target(reflection, model_was, foreign_key_was).update_counters(cache_column => -1)
            end
          end
        end

        private
          def counter_cache_target(reflection, model, foreign_key)
            primary_key = reflection.association_primary_key(model)
            model.unscoped.where!(primary_key => foreign_key)
          end
      end
    end

    def self.add_counter_cache_callbacks(model, reflection)
      cache_column = reflection.counter_cache_column

      model.after_update lambda { |record|
        record.belongs_to_counter_cache_after_update(reflection)
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
            old_record.send(touch_method, touch)
          else
            old_record.send(touch_method)
          end
        end
      end

      record = o.send name
      if record && record.persisted?
        if touch != true
          record.send(touch_method, touch)
        else
          record.send(touch_method)
        end
      end
    end

    def self.add_touch_callbacks(model, reflection)
      foreign_key = reflection.foreign_key
      n           = reflection.name
      touch       = reflection.options[:touch]

      callback = lambda { |changes_method| lambda { |record|
        BelongsTo.touch_record(record, record.send(changes_method), foreign_key, n, touch, belongs_to_touch_method)
      }}

      unless reflection.counter_cache_column
        model.after_create callback.(:saved_changes), if: :saved_changes?
        model.after_destroy callback.(:changes_to_save)
      end

      model.after_update callback.(:saved_changes), if: :saved_changes?
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
  end
end
