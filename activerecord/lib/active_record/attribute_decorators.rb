module ActiveRecord
  module AttributeDecorators # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :attribute_type_decorations, instance_accessor: false # :internal:
      self.attribute_type_decorations = TypeDecorator.new
    end

    module ClassMethods # :nodoc:
      def decorate_attribute_type(column_name, decorator_name, &block)
        matcher = ->(name, _) { name == column_name.to_s }
        key = "_#{column_name}_#{decorator_name}"
        decorate_matching_attribute_types(matcher, key, &block)
      end

      def decorate_matching_attribute_types(matcher, decorator_name, &block)
        reload_schema_from_cache
        decorator_name = decorator_name.to_s

        # Create new hashes so we don't modify parent classes
        self.attribute_type_decorations = attribute_type_decorations.merge(decorator_name => [matcher, block])
      end

      private

      def load_schema!
        super
        attribute_types.each do |name, type|
          decorated_type = attribute_type_decorations.apply(name, type)
          define_attribute(name, decorated_type)
        end
      end
    end

    class TypeDecorator # :nodoc:
      delegate :clear, to: :@decorations

      def initialize(decorations = {})
        @decorations = decorations
      end

      def merge(*args)
        TypeDecorator.new(@decorations.merge(*args))
      end

      def apply(name, type)
        decorations = decorators_for(name, type)
        decorations.inject(type) do |new_type, block|
          block.call(new_type)
        end
      end

      private

      def decorators_for(name, type)
        matching(name, type).map(&:last)
      end

      def matching(name, type)
        @decorations.values.select do |(matcher, _)|
          matcher.call(name, type)
        end
      end
    end
  end
end
