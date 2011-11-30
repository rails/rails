require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/array/wrap'


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
  #       {'name' => name}
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
  # serializations. Both of these modules automatically include the
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
  #       {'name' => name}
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

      attribute_names = attributes.keys.sort
      if only = options[:only]
        attribute_names &= Array.wrap(only).map(&:to_s)
      elsif except = options[:except]
        attribute_names -= Array.wrap(except).map(&:to_s)
      end

      hash = {}
      attribute_names.each { |n| hash[n] = read_attribute_for_serialization(n) }

      method_names = Array.wrap(options[:methods]).select { |n| respond_to?(n) }
      method_names.each { |n| hash[n] = send(n) }

      serializable_add_includes(options) do |association, records, opts|
        hash[association] = if records.is_a?(Enumerable)
          records.map { |a| a.serializable_hash(opts) }
        else
          records.serializable_hash(opts)
        end
      end

      hash
    end

    private

      # Hook method defining how an attribute value should be retrieved for
      # serialization. By default this is assumed to be an instance named after
      # the attribute. Override this method in subclasses should you need to
      # retrieve the value for a given attribute differently:
      #
      #   class MyClass
      #     include ActiveModel::Validations
      #
      #     def initialize(data = {})
      #       @data = data
      #     end
      #
      #     def read_attribute_for_serialization(key)
      #       @data[key]
      #     end
      #   end
      #
      alias :read_attribute_for_serialization :send

      # Add associations specified via the <tt>:include</tt> option.
      #
      # Expects a block that takes as arguments:
      #   +association+ - name of the association
      #   +records+     - the association record(s) to be serialized
      #   +opts+        - options for the association records
      def serializable_add_includes(options = {}) #:nodoc:
        return unless include = options[:include]

        unless include.is_a?(Hash)
          include = Hash[Array.wrap(include).map { |n| n.is_a?(Hash) ? n.to_a.first : [n, {}] }]
        end

        include.each do |association, opts|
          if records = send(association)
            yield association, records, opts
          end
        end
      end
  end
end
