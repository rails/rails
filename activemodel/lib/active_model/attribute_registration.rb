# frozen_string_literal: true

require "active_support/core_ext/class/subclasses"
require "active_model/attribute_set"
require "active_model/attribute/user_provided_default"

module ActiveModel
  module AttributeRegistration # :nodoc:
    extend ActiveSupport::Concern

    module ClassMethods # :nodoc:
      def attribute(name, type = nil, default: (no_default = true), **options)
        name = resolve_attribute_name(name)
        type = resolve_type_name(type, **options) if type.is_a?(Symbol)
        type = hook_attribute_type(name, type) if type

        pending_attribute_modifications << PendingType.new(name, type) if type || no_default
        pending_attribute_modifications << PendingDefault.new(name, default) unless no_default

        reset_default_attributes
      end

      def decorate_attributes(names = nil, &decorator) # :nodoc:
        names = names&.map { |name| resolve_attribute_name(name) }

        pending_attribute_modifications << PendingDecorator.new(names, decorator)

        reset_default_attributes
      end

      def _default_attributes # :nodoc:
        @default_attributes ||= AttributeSet.new({}).tap do |attribute_set|
          apply_pending_attribute_modifications(attribute_set)
        end
      end

      def attribute_types # :nodoc:
        @attribute_types ||= _default_attributes.cast_types.tap do |hash|
          hash.default = Type.default_value
        end
      end

      def type_for_attribute(attribute_name, &block)
        attribute_name = resolve_attribute_name(attribute_name)

        if block
          attribute_types.fetch(attribute_name, &block)
        else
          attribute_types[attribute_name]
        end
      end

      private
        PendingType = Struct.new(:name, :type) do # :nodoc:
          def apply_to(attribute_set)
            attribute = attribute_set[name]
            attribute_set[name] = attribute.with_type(type || attribute.type)
          end
        end

        PendingDefault = Struct.new(:name, :default) do # :nodoc:
          def apply_to(attribute_set)
            attribute_set[name] = attribute_set[name].with_user_default(default)
          end
        end

        PendingDecorator = Struct.new(:names, :decorator) do # :nodoc:
          def apply_to(attribute_set)
            (names || attribute_set.keys).each do |name|
              attribute = attribute_set[name]
              type = decorator.call(name, attribute.type)
              attribute_set[name] = attribute.with_type(type) if type
            end
          end
        end

        def pending_attribute_modifications
          @pending_attribute_modifications ||= []
        end

        def apply_pending_attribute_modifications(attribute_set)
          if superclass.respond_to?(:apply_pending_attribute_modifications, true)
            superclass.send(:apply_pending_attribute_modifications, attribute_set)
          end

          pending_attribute_modifications.each do |modification|
            modification.apply_to(attribute_set)
          end
        end

        def reset_default_attributes
          reset_default_attributes!
          subclasses.each { |subclass| subclass.send(:reset_default_attributes) }
        end

        def reset_default_attributes!
          @default_attributes = nil
          @attribute_types = nil
        end

        def resolve_attribute_name(name)
          name.to_s
        end

        def resolve_type_name(name, **options)
          Type.lookup(name, **options)
        end

        # Hook for other modules to override. The attribute type is passed
        # through this method immediately after it is resolved, before any type
        # decorations are applied.
        def hook_attribute_type(attribute, type)
          type
        end
    end
  end
end
