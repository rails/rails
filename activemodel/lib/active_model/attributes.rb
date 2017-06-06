module ActiveModel
  module Attributes
    extend ActiveSupport::Concern

    included do
      class_attribute :attributes_registry, instance_accessor: false
      self.attributes_registry = {}
    end

    module ClassMethods
      NO_DEFAULT_PROVIDED = Object.new
      private_constant :NO_DEFAULT_PROVIDED

      def attribute(name, cast_type, **options)
        self.attributes_registry = attributes_registry.merge(name => [cast_type, options])

        define_attribute_reader(name, options)
        define_attribute_writer(name, cast_type, options)
      end

      def define_attribute_reader(name, options)
        provided_default = options.fetch(:default) { NO_DEFAULT_PROVIDED }
        define_method name do
          return instance_variable_get("@#{name}") if instance_variable_defined?("@#{name}")
          return if provided_default == NO_DEFAULT_PROVIDED
          provided_default.respond_to?(:call) && provided_default.call || provided_default
        end
      end

      def define_attribute_writer(name, cast_type, options)
        define_method "#{name}=" do |val|
          deserialized_value = ActiveModel::Type.lookup(cast_type).deserialize(val)
          instance_variable_set("@#{name}", deserialized_value)
        end
      end
    end
  end
end
