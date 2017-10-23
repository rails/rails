# frozen_string_literal: true

require "active_model/type"

module ActiveModel
  module Attributes #:nodoc:
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods
    include ActiveModel::Dirty

    included do
      attribute_method_suffix "="
      class_attribute :attribute_types, :_default_attributes, instance_accessor: false
      self.attribute_types = {}
      self._default_attributes = {}
    end

    module ClassMethods
      def attribute(name, cast_type = Type::Value.new, **options)
        self.attribute_types = attribute_types.merge(name.to_s => cast_type)
        self._default_attributes = _default_attributes.merge(name.to_s => options[:default])
        define_attribute_methods(name)
      end

      private

        def define_method_attribute=(name)
          safe_name = name.unpack("h*".freeze).first
          ActiveModel::AttributeMethods::AttrNames.set_name_cache safe_name, name

          generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
            def __temp__#{safe_name}=(value)
              name = ::ActiveModel::AttributeMethods::AttrNames::ATTR_#{safe_name}
              write_attribute(name, value)
            end
            alias_method #{(name + '=').inspect}, :__temp__#{safe_name}=
            undef_method :__temp__#{safe_name}=
          STR
        end
    end

    def initialize(*)
      super
      clear_changes_information
    end

    private

      def write_attribute(attr_name, value)
        name = if self.class.attribute_alias?(attr_name)
          self.class.attribute_alias(attr_name).to_s
        else
          attr_name.to_s
        end

        cast_type = self.class.attribute_types[name]

        deserialized_value = ActiveModel::Type.lookup(cast_type).cast(value)
        attribute_will_change!(name) unless deserialized_value == attribute(name)
        instance_variable_set("@#{name}", deserialized_value)
        deserialized_value
      end

      def attribute(name)
        if instance_variable_defined?("@#{name}")
          instance_variable_get("@#{name}")
        else
          default = self.class._default_attributes[name]
          default.respond_to?(:call) ? default.call : default
        end
      end

      # Handle *= for method_missing.
      def attribute=(attribute_name, value)
        write_attribute(attribute_name, value)
      end
  end

  module AttributeMethods #:nodoc:
    AttrNames = Module.new {
      def self.set_name_cache(name, value)
        const_name = "ATTR_#{name}"
        unless const_defined? const_name
          const_set const_name, value.dup.freeze
        end
      end
    }
  end
end
