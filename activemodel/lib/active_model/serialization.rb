require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

module ActiveModel
  # == Active Model Serialization
  #
  # Provides a basic serialization to a serializable_hash for your object.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #
  #     include ActiveModel::Serialization
  #
  #     attr_accessor :name
  #
  #     def attributes
  #       @attributes ||= {'name' => 'nil'}
  #     end
  #
  #   end
  #
  # Which would provide you with:
  #
  #   person = Person.new
  #   person.serializable_hash   # => {"name"=>nil}
  #   person.name = "Bob"
  #   person.serializable_hash   # => {"name"=>"Bob"}
  #
  # You need to declare some sort of attributes hash which contains the attributes
  # you want to serialize and their current value.
  #
  # Most of the time though, you will want to include the JSON or XML
  # serializations.  Both of these modules automatically include the
  # ActiveModel::Serialization module, so there is no need to explicitly
  # include it.
  #
  # So a minimal implementation including XML and JSON would be:
  #
  #   class Person
  #
  #     include ActiveModel::Serializers::JSON
  #     include ActiveModel::Serializers::Xml
  #
  #     attr_accessor :name
  #
  #     def attributes
  #       @attributes ||= {'name' => 'nil'}
  #     end
  #
  #   end
  #
  # Which would provide you with:
  #
  #   person = Person.new
  #   person.serializable_hash   # => {"name"=>nil}
  #   person.as_json             # => {"name"=>nil}
  #   person.to_json             # => "{\"name\":null}"
  #   person.to_xml              # => "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<serial-person...
  #
  #   person.name = "Bob"
  #   person.serializable_hash   # => {"name"=>"Bob"}
  #   person.as_json             # => {"name"=>"Bob"}
  #   person.to_json             # => "{\"name\":\"Bob\"}"
  #   person.to_xml              # => "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<serial-person...
  #
  # Valid options are <tt>:only</tt>, <tt>:except</tt> and <tt>:methods</tt> .
  module Serialization
    def serializable_hash(options = nil)
      options ||= {}

      only   = Array.wrap(options[:only]).map(&:to_s)
      except = Array.wrap(options[:except]).map(&:to_s)

      attribute_names = attributes.keys.sort
      if only.any?
        attribute_names &= only
      elsif except.any?
        attribute_names -= except
      end

      method_names = Array.wrap(options[:methods]).inject([]) do |methods, name|
        methods << name if respond_to?(name.to_s)
        methods
      end

      (attribute_names + method_names).inject({}) { |hash, name|
        hash[name] = send(name)
        hash
      }
    end
  end
end
