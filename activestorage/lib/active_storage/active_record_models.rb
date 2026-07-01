# frozen_string_literal: true

return if ActiveStorage.instance_variable_defined?(:@active_record_models_loaded)

ActiveStorage.instance_variable_set(:@active_record_models_loaded, true)

require "active_storage/attached"
require "active_storage/reflection"

module ActiveStorage::Reflection
  class HasAttachedReflection < ::ActiveRecord::Reflection::MacroReflection # :nodoc:
    def variant(name, transformations)
      named_variants[name] = ActiveStorage::NamedVariant.new(transformations)
    end

    def named_variants
      @named_variants ||= {}
    end
  end

  # Holds all the metadata about a has_one_attached attachment as it was
  # specified in the Active Record class.
  class HasOneAttachedReflection < HasAttachedReflection # :nodoc:
    def macro
      :has_one_attached
    end
  end

  # Holds all the metadata about a has_many_attached attachment as it was
  # specified in the Active Record class.
  class HasManyAttachedReflection < HasAttachedReflection # :nodoc:
    def macro
      :has_many_attached
    end
  end

  module ReflectionExtension # :nodoc:
    def add_attachment_reflection(model, name, reflection)
      model.attachment_reflections = model.attachment_reflections.merge(name.to_s => reflection)
    end

    private
      def reflection_class_for(macro)
        case macro
        when :has_one_attached
          HasOneAttachedReflection
        when :has_many_attached
          HasManyAttachedReflection
        else
          super
        end
      end
  end

  module ActiveRecordExtensions
    extend ActiveSupport::Concern
    include Extensions
  end
end

::ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)
::ActiveRecord::Base.include(ActiveStorage::Attached::Model)
::ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
