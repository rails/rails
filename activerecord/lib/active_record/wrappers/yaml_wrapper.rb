require 'yaml'

module ActiveRecord
  module Wrappings #:nodoc:
    class YamlWrapper < AbstractWrapper #:nodoc:
      def wrap(attribute)   attribute.to_yaml end
      def unwrap(attribute) YAML::load(attribute) end
    end

    module ClassMethods #:nodoc:
      # Wraps the attribute in Yaml encoding
      def wrap_in_yaml(*attributes) wrap_with(YamlWrapper, attributes) end
    end
  end
end