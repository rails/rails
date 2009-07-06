require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

module ActiveModel
  class Serializer
    attr_reader :options

    def initialize(serializable, options = nil)
      @serializable = serializable
      @options = options ? options.dup : {}

      @options[:only] = Array.wrap(@options[:only]).map { |n| n.to_s }
      @options[:except] = Array.wrap(@options[:except]).map { |n| n.to_s }
    end

    def serialize
      raise NotImplemented
    end

    def to_s(&block)
      serialize(&block)
    end

    # To replicate the behavior in ActiveRecord#attributes,
    # <tt>:except</tt> takes precedence over <tt>:only</tt>.  If <tt>:only</tt> is not set
    # for a N level model but is set for the N+1 level models,
    # then because <tt>:except</tt> is set to a default value, the second
    # level model can have both <tt>:except</tt> and <tt>:only</tt> set.  So if
    # <tt>:only</tt> is set, always delete <tt>:except</tt>.
    def serializable_attribute_names
      attribute_names = @serializable.attributes.keys.sort

      if options[:only].any?
        attribute_names &= options[:only]
      elsif options[:except].any?
        attribute_names -= options[:except]
      end

      attribute_names
    end

    def serializable_method_names
      Array.wrap(options[:methods]).inject([]) do |methods, name|
        methods << name if @serializable.respond_to?(name.to_s)
        methods
      end
    end

    def serializable_names
      serializable_attribute_names + serializable_method_names
    end

    def serializable_hash
      serializable_names.inject({}) { |hash, name|
        hash[name] = @serializable.send(name)
        hash
      }
    end
  end
end
