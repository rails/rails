module ActiveRecord::Associations::Builder
  class BelongsTo < SingularAssociation #:nodoc:
    def macro
      :belongs_to
    end

    def valid_options
      super + [:foreign_type, :polymorphic, :touch]
    end

    def constructable?
      !options[:polymorphic]
    end

    def build
      reflection = super
      add_counter_cache_callbacks(reflection) if options[:counter_cache]
      add_touch_callbacks(reflection)         if options[:touch]
      reflection
    end

    def add_counter_cache_callbacks(reflection)
      cache_column = reflection.counter_cache_column

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def belongs_to_counter_cache_after_create_for_#{name}
          record = #{name}
          record.class.increment_counter(:#{cache_column}, record.id) unless record.nil?
        end

        def belongs_to_counter_cache_before_destroy_for_#{name}
          unless marked_for_destruction?
            record = #{name}
            record.class.decrement_counter(:#{cache_column}, record.id) unless record.nil?
          end
        end
      CODE

      model.after_create   "belongs_to_counter_cache_after_create_for_#{name}"
      model.before_destroy "belongs_to_counter_cache_before_destroy_for_#{name}"

      klass = reflection.class_name.safe_constantize
      klass.attr_readonly cache_column if klass && klass.respond_to?(:attr_readonly)
    end

    def add_touch_callbacks(reflection)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def belongs_to_touch_after_save_or_destroy_for_#{name}
          record = #{name}

          unless record.nil?
            record.touch #{options[:touch].inspect if options[:touch] != true}
          end
        end
      CODE

      model.after_save    "belongs_to_touch_after_save_or_destroy_for_#{name}"
      model.after_touch   "belongs_to_touch_after_save_or_destroy_for_#{name}"
      model.after_destroy "belongs_to_touch_after_save_or_destroy_for_#{name}"
    end

    def valid_dependent_options
      [:destroy, :delete]
    end
  end
end
