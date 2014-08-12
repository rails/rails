require 'yaml'

module ActiveRecord
  module Coders # :nodoc:
    class YAML # :nodoc:
      def self.serialize_for_database(obj)
        ::YAML.dump obj
      end

      def self.deserialize_from_database(yaml)
        ::YAML.load yaml
      end
    end
  end
end
