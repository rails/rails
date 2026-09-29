# frozen_string_literal: true

# :markup: markdown

class ActiveStorage::Attached::Builder # :nodoc:
  autoload :ActiveRecordOwner, "active_storage/attached/builder/active_record_owner"
  autoload :Generic, "active_storage/attached/builder/generic"

  def self.for(model)
    if active_record_owner?(model)
      ActiveRecordOwner.new(model)
    else
      Generic.new(model)
    end
  end

  def self.active_record_owner?(model)
    defined?(::ActiveRecord::Base) && !::ActiveRecord.autoload?(:Base) && model < ::ActiveRecord::Base
  end

  # Resolve loaded constants afresh without autoloading owners during code reloading.
  def self.declared_classes
    declared_class_registry.keys.filter_map do |name|
      model = name.split("::").inject(Object) do |namespace, constant|
        break unless namespace.is_a?(Module) && namespace.const_defined?(constant, false)
        break if namespace.autoload?(constant, false)

        namespace.const_get(constant, false)
      end
      model if model.respond_to?(:attachment_reflections) && model.attachment_reflections.any?
    end
  end

  def self.declared_class_registry
    @declared_class_registry ||= Concurrent::Map.new
  end

  def self.register(model)
    declared_class_registry[model.name] = true if model.name
  end
end
