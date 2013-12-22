module ActiveRecord::Associations::Builder
  class BelongsTo < SingularAssociation #:nodoc:
    def macro
      :belongs_to
    end

    def valid_options
      super + [:foreign_type, :polymorphic, :touch, :counter_cache]
    end

    def self.valid_dependent_options
      [:destroy, :delete]
    end

    def self.define_callbacks(model, reflection)
      super
      add_counter_cache_callbacks(model, reflection) if reflection.options[:counter_cache]
      add_touch_callbacks(model, reflection)         if reflection.options[:touch]
    end

    def self.define_accessors(mixin, reflection)
      super
      add_counter_cache_methods mixin
    end

    private

    def self.add_counter_cache_methods(mixin)
      return if mixin.method_defined? :belongs_to_counter_cache_after_create

      mixin.class_eval do
        def belongs_to_counter_cache_after_create(reflection)
          if record = send(reflection.name)
            cache_column = reflection.counter_cache_column
            record.class.increment_counter(cache_column, record.id)
            @_after_create_counter_called = true
          end
        end

        def belongs_to_counter_cache_before_destroy(reflection)
          foreign_key = reflection.foreign_key.to_sym
          unless destroyed_by_association && destroyed_by_association.foreign_key.to_sym == foreign_key
            record = send reflection.name
            if record && !self.destroyed?
              cache_column = reflection.counter_cache_column
              record.class.decrement_counter(cache_column, record.id)
            end
          end
        end

        def belongs_to_counter_cache_after_update(reflection)
          foreign_key  = reflection.foreign_key
          cache_column = reflection.counter_cache_column

          if (@_after_create_counter_called ||= false)
            @_after_create_counter_called = false
          elsif attribute_changed?(foreign_key) && !new_record? && reflection.constructable?
            model           = reflection.klass
            foreign_key_was = attribute_was foreign_key
            foreign_key     = attribute foreign_key

            if foreign_key && model.respond_to?(:increment_counter)
              model.increment_counter(cache_column, foreign_key)
            end
            if foreign_key_was && model.respond_to?(:decrement_counter)
              model.decrement_counter(cache_column, foreign_key_was)
            end
          end
        end
      end
    end

    def self.add_counter_cache_callbacks(model, reflection)
      cache_column = reflection.counter_cache_column

      model.after_create lambda { |record|
        record.belongs_to_counter_cache_after_create(reflection)
      }

      model.before_destroy lambda { |record|
        record.belongs_to_counter_cache_before_destroy(reflection)
      }

      model.after_update lambda { |record|
        record.belongs_to_counter_cache_after_update(reflection)
      }

      klass = reflection.class_name.safe_constantize
      klass.attr_readonly cache_column if klass && klass.respond_to?(:attr_readonly)
    end

    def self.touch_record(o, foreign_key, name, touch) # :nodoc:
      old_foreign_id = o.changed_attributes[foreign_key]

      if old_foreign_id
        association = o.association(name)
        reflection = association.reflection
        if reflection.polymorphic?
          klass = o.public_send("#{reflection.foreign_type}_was").constantize
        else
          klass = association.klass
        end
        old_record = klass.find_by(klass.primary_key => old_foreign_id)

        if old_record
          if touch != true
            old_record.touch touch
          else
            old_record.touch
          end
        end
      end

      record = o.send name
      if record && record.persisted?
        if touch != true
          record.touch touch
        else
          record.touch
        end
      end
    end

    def self.add_touch_callbacks(model, reflection)
      foreign_key = reflection.foreign_key
      n           = reflection.name
      touch       = reflection.options[:touch]

      callback = lambda { |record|
        BelongsTo.touch_record(record, foreign_key, n, touch)
      }

      model.after_save    callback
      model.after_touch   callback
      model.after_destroy callback
    end
  end
end
