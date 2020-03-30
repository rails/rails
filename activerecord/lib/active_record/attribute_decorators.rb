# frozen_string_literal: true

module ActiveRecord
  module AttributeDecorators # :nodoc:
    extend ActiveSupport::Concern

    module ClassMethods # :nodoc:
      def deferred_attribute_type_decorations
        @deferred_attribute_type_decorations ||= {}
      end

      # This method is an internal API used to create class macros such as
      # +serialize+, and features like time zone aware attributes.
      #
      # Used to wrap the type of an attribute in a new type.
      # When the schema for a model is loaded, attributes with the same name as
      # +column_name+ will have their type yielded to the given block. The
      # return value of that block will be used instead.
      #
      # Subsequent calls where +column_name+ and +decorator_name+ are the same
      # will override the previous decorator, not decorate twice. This can be
      # used to create idempotent class macros like +serialize+
      def decorate_attribute_type(column_name, decorator_name, &block)
        matcher = ->(name, _) { name == column_name.to_s }
        key = "_#{column_name}_#{decorator_name}"
        decorate_matching_attribute_types(matcher, key, &block)
      end

      # This method is an internal API used to create higher level features like
      # time zone aware attributes.
      #
      # When the schema for a model is loaded, +matcher+ will be called for each
      # attribute with its name and type. If the matcher returns a truthy value,
      # the type will then be yielded to the given block, and the return value
      # of that block will replace the type.
      #
      # Subsequent calls to this method with the same value for +decorator_name+
      # will replace the previous decorator, not decorate twice. This can be
      # used to ensure that class macros are idempotent.
      def decorate_matching_attribute_types(matcher, decorator_name, &block)
        reload_schema_from_cache
        deferred_attribute_type_decorations[decorator_name.to_s] = [matcher, block]
      end

      private
        def load_schema!
          super

          deferred = ancestors.map { |klass| klass.try(:deferred_attribute_type_decorations) }.compact.reduce(&:reverse_merge)

          attribute_types.each do |name, type|
            decorated_type = deferred.each_value.reduce(type) do |t, (matcher, block)|
              matcher.call(name, type) ? block.call(t) : t
            end
            define_attribute(name, decorated_type)
          end
        end
    end
  end
end
