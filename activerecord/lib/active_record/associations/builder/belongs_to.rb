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
        def belongs_to_counter_cache_after_create_for_#{reflection.foreign_key}
          record = #{name}
          record.class.increment_counter(:#{cache_column}, record.id) unless record.nil?
        end

        def belongs_to_counter_cache_before_destroy_for_#{reflection.foreign_key}
          unless marked_for_destruction?
            record = #{name}
            record.class.decrement_counter(:#{cache_column}, record.id) unless record.nil?
          end
        end
      CODE

      if options[:polymorphic]
        mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def belongs_to_counter_cache_after_update_for_#{reflection.foreign_key}
            type_change = #{reflection.foreign_type}_change
            value_change = #{reflection.foreign_key}_change

            return if type_change.nil? && value_change.nil?
            if type_change.nil? && value_change
              klass = #{reflection.foreign_type}.safe_constantize
              klass.decrement_counter(:#{cache_column}, value_change[0]) unless value_change[0].nil?
              klass.increment_counter(:#{cache_column}, value_change[1]) unless value_change[1].nil?
            elsif type_change and value_change
              return if type_change[0].nil? && value_change[0].nil?
              unless type_change[0].nil? || value_change[0].nil?
                type_change[0].safe_constantize.decrement_counter(:#{cache_column}, value_change[0])
              end
              unless type_change[1].nil? || value_change[1].nil?
                type_change[1].safe_constantize.increment_counter(:#{cache_column}, value_change[1])
              end
            else
              unless type_change[0].nil?
                type_change[0].safe_constantize.decrement_counter(:#{cache_column}, #{reflection.foreign_key})
              end
              unless type_change[1].nil?
                type_change[1].safe_constantize.increment_counter(:#{cache_column}, #{reflection.foreign_key})
              end
            end
          end
        CODE
      elsif options[:primary_key]
        mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def belongs_to_counter_cache_after_update_for_#{reflection.foreign_key}
            if change = #{reflection.foreign_key}_change
              unless change[0].nil?
                #{reflection.class_name}.decrement_counter(:#{cache_column}, change[0], "#{ options[:primary_key].to_s }")
              end
              unless change[1].nil?
                #{reflection.class_name}.increment_counter(:#{cache_column}, change[1], "#{ options[:primary_key].to_s }")
              end
            end
          end
        CODE
      else
        mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def belongs_to_counter_cache_after_update_for_#{reflection.foreign_key}
            if change = #{reflection.foreign_key}_change
              #{reflection.class_name}.decrement_counter(:#{cache_column}, change[0]) unless change[0].nil?
              #{reflection.class_name}.increment_counter(:#{cache_column}, change[1]) unless change[1].nil?
            end
          end
        CODE
      end

      model.after_create   "belongs_to_counter_cache_after_create_for_#{reflection.foreign_key}"
      model.before_destroy "belongs_to_counter_cache_before_destroy_for_#{reflection.foreign_key}"
      model.after_update "belongs_to_counter_cache_after_update_for_#{reflection.foreign_key}"

      klass = reflection.class_name.safe_constantize
      klass.attr_readonly cache_column if klass && klass.respond_to?(:attr_readonly)
    end

    def add_touch_callbacks(reflection)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def belongs_to_touch_after_save_or_destroy_for_#{reflection.foreign_key}
          record = #{name}

          unless record.nil?
            record.touch #{options[:touch].inspect if options[:touch] != true}
          end
        end
      CODE

      model.after_save    "belongs_to_touch_after_save_or_destroy_for_#{reflection.foreign_key}"
      model.after_touch   "belongs_to_touch_after_save_or_destroy_for_#{reflection.foreign_key}"
      model.after_destroy "belongs_to_touch_after_save_or_destroy_for_#{reflection.foreign_key}"
    end

    def valid_dependent_options
      [:destroy, :delete]
    end
  end
end
