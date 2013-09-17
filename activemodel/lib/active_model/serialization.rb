require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

module ActiveModel
  # == Active \Model \Serialization
  #
  # Provides a basic serialization to a serializable_hash for your object.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::Serialization
  #
  #     attr_accessor :name
  #
  #     def attributes
  #       {'name' => nil}
  #     end
  #   end
  #
  # Which would provide you with:
  #
  #   person = Person.new
  #   person.serializable_hash   # => {"name"=>nil}
  #   person.name = "Bob"
  #   person.serializable_hash   # => {"name"=>"Bob"}
  #
  # You need to declare an attributes hash which contains the attributes you
  # want to serialize. Attributes must be strings, not symbols. When called,
  # serializable hash will use instance methods that match the name of the
  # attributes hash's keys. In order to override this behavior, take a look at
  # the private method +read_attribute_for_serialization+.
  #
  # Most of the time though, you will want to include the JSON or XML
  # serializations. Both of these modules automatically include the
  # <tt>ActiveModel::Serialization</tt> module, so there is no need to
  # explicitly include it.
  #
  # A minimal implementation including XML and JSON would be:
  #
  #   class Person
  #     include ActiveModel::Serializers::JSON
  #     include ActiveModel::Serializers::Xml
  #
  #     attr_accessor :name
  #
  #     def attributes
  #       {'name' => nil}
  #     end
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
  # Valid options are <tt>:only</tt>, <tt>:except</tt>, <tt>:methods</tt> and
  # <tt>:include</tt>. The following are all valid examples:
  #
  #   person.serializable_hash(only: 'name')
  #   person.serializable_hash(include: :address)
  #   person.serializable_hash(include: { address: { only: 'city' }})
  #
  # <tt>:only</tt> and <tt>:methods</tt> also accept a Hash, in which the key is the name of the
  # attribute to serialize and the value is the key in which to store the result. For example:
  #
  #   person.to_json(only: {name: :real_name})
  #     => "{\"real_name\":\"Bob\"}"
  #   person.to_json(methods: {full_name: :real_name})
  #     => "{\"real_name\":\"Bob McKenzie\"}"
  #
  # <tt>:include</tt> also accepts a <tt>:root</tt> option that specifies the name where the
  # association will be stored
  #
  #   person.to_json(only: :name, include: {children: {root: :kids, only: :name}})
  #     => "{\"name\":\"Bob\",\"kids\":[{\"name\":\"Jimmy\"}]}"
  #   
  module Serialization
    # Returns a serialized hash of your object.
    #
    #   class Person
    #     include ActiveModel::Serialization
    #
    #     attr_accessor :name, :age
    #
    #     def attributes
    #       {'name' => nil, 'age' => nil}
    #     end
    #
    #     def capitalized_name
    #       name.capitalize
    #     end
    #   end
    #
    #   person = Person.new
    #   person.name = 'bob'
    #   person.age  = 22
    #   person.serializable_hash                # => {"name"=>"bob", "age"=>22}
    #   person.serializable_hash(only: :name)   # => {"name"=>"bob"}
    #   person.serializable_hash(except: :name) # => {"age"=>22}
    #   person.serializable_hash(methods: :capitalized_name)
    #   # => {"name"=>"bob", "age"=>22, "capitalized_name"=>"Bob"}
    def serializable_hash(options = nil)
      options ||= {}

      attribute_names = attributes.keys
      if only = options[:only]
        attribute_names &= if only.is_a?(Hash)
          only.keys.map(&:to_s)
        else
          Array(only).map(&:to_s)
        end
      elsif except = options[:except]
        attribute_names -= Array(except).map(&:to_s)
      end

      hash = {}
      attribute_names.each { |n|
        key = only && only.is_a?(Hash) ? (only[n] || only[n.to_sym]).to_s : n
        hash[key] = read_attribute_for_serialization(n)
      }
      
      Array(options[:methods]).each { |m| 
        n, key = m.is_a?(Array) ? m.map(&:to_s) : [m.to_s] * 2
        hash[key] = send(n) if respond_to?(n)
      }

      serializable_add_includes(options) do |association, records, opts|
        key = opts[:root] || association
        hash[key.to_s] = if records.respond_to?(:to_ary)
          records.to_ary.map { |a| a.serializable_hash(opts) }
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
      alias :read_attribute_for_serialization :send

      # Add associations specified via the <tt>:include</tt> option.
      #
      # Expects a block that takes as arguments:
      #   +association+ - name of the association
      #   +records+     - the association record(s) to be serialized
      #   +opts+        - options for the association records
      def serializable_add_includes(options = {}) #:nodoc:
        return unless includes = options[:include]

        unless includes.is_a?(Hash)
          includes = Hash[Array(includes).map { |n| n.is_a?(Hash) ? n.to_a.first : [n, {}] }]
        end

        includes.each do |association, opts|
          if records = send(association)
            yield association, records, opts
          end
        end
      end
  end
end
