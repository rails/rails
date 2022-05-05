# frozen_string_literal: true

require "active_support/core_ext/class/subclasses"
require "active_model/attribute_set"
require "active_model/attribute/user_provided_default"

module ActiveModel
  module AttributeRegistration # :nodoc:
    extend ActiveSupport::Concern

    module ClassMethods # :nodoc:
      def attribute(name, type = nil, default: (no_default = true), **options)
        type = resolve_type_name(type, **options) if type.is_a?(Symbol)

        pending = pending_attribute(name)
        pending.type = type if type
        pending.default = default unless no_default

        reset_default_attributes
      end

      def _default_attributes # :nodoc:
        @default_attributes ||= build_default_attributes
      end

      def attribute_types # :nodoc:
        @attribute_types ||= _default_attributes.cast_types.tap do |hash|
          hash.default = Type.default_value
        end
      end

      private
        class PendingAttribute # :nodoc:
          attr_accessor :type, :default

          def apply_to(attribute)
            attribute = attribute.with_type(type || attribute.type)
            attribute = attribute.with_user_default(default) if defined?(@default)
            attribute
          end
        end

        def pending_attribute(name)
          @pending_attributes ||= {}
          @pending_attributes[resolve_attribute_name(name)] ||= PendingAttribute.new
        end

        def apply_pending_attributes(attribute_set)
          superclass.send(__method__, attribute_set) if superclass.respond_to?(__method__, true)

          defined?(@pending_attributes) && @pending_attributes.each do |name, pending|
            attribute_set[name] = pending.apply_to(attribute_set[name])
          end

          attribute_set
        end

        def build_default_attributes
          apply_pending_attributes(AttributeSet.new({}))
        end

        def reset_default_attributes
          @default_attributes = nil
          @attribute_types = nil
          subclasses.each { |subclass| subclass.send(__method__) }
        end

        def resolve_attribute_name(name)
          name.to_s
        end

        def resolve_type_name(name, **options)
          Type.lookup(name, **options)
        end
    end
  end
end
