# frozen_string_literal: true

module ActiveSupport
  module DeepTransformObject # :nodoc:
    module_function

    def deep_transform_keys(object, &block)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          result[yield(key)] = deep_transform_keys(value, &block)
        end
      when Array
        object.map { |e| deep_transform_keys(e, &block) }
      else
        object
      end
    end

    def deep_transform_keys!(object, &block)
      case object
      when Hash
        object.keys.each do |key|
          value = object.delete(key)
          object[yield(key)] = deep_transform_keys!(value, &block)
        end
        object
      when Array
        object.map! { |e| deep_transform_keys!(e, &block) }
      else
        object
      end
    end

    def deep_transform_values(object, &block)
      case object
      when Hash
        object.transform_values { |value| deep_transform_values(value, &block) }
      when Array
        object.map { |e| deep_transform_values(e, &block) }
      else
        yield(object)
      end
    end

    def deep_transform_values!(object, &block)
      case object
      when Hash
        object.transform_values! { |value| deep_transform_values!(value, &block) }
      when Array
        object.map! { |e| deep_transform_values!(e, &block) }
      else
        yield(object)
      end
    end
  end
end
