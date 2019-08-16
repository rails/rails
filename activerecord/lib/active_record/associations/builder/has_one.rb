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

    def self.valid_dependent_options
      [:destroy, :delete, :nullify, :restrict_with_error, :restrict_with_exception]
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

    def self.define_readers(mixin, name)
      super

      model_class = mixin.module_parent
      association_name = name.to_s.singularize
      association_id_reader_name = "#{association_name}_id"
      is_association_id_column_absent = !!model_class.try(:table_exists?) && model_class.column_names.exclude?(association_id_reader_name)
      belongs_to_associations = model_class.respond_to?(:reflect_on_all_associations) ?  model_class.reflect_on_all_associations(:belongs_to).map(&:name) : []
      is_a_belongs_to_association = belongs_to_associations.include?(association_name.to_sym)

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{association_id_reader_name}
          is_custom_attribute = #{is_association_id_column_absent} && has_attribute?(:#{association_id_reader_name})

          if #{is_a_belongs_to_association} || is_custom_attribute
            attributes["#{association_id_reader_name}"]
          else
            association(:#{name}).id_reader
          end
        end
      CODE
    end

    def self.define_writers(mixin, name)
      super

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name.to_s.singularize}_id=(id)
          association(:#{name}).id_writer(id)
        end
      CODE
    end

    private_class_method :macro, :valid_options, :valid_dependent_options, :add_destroy_callbacks,
      :define_callbacks, :define_validations, :add_touch_callbacks, :define_readers, :define_writers
  end
end
