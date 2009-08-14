require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

module ActiveModel
  module Serialization
    def serializable_hash(options = nil)
      options ||= {}

      options[:only]   = Array.wrap(options[:only]).map { |n| n.to_s }
      options[:except] = Array.wrap(options[:except]).map { |n| n.to_s }

      attribute_names = attributes.keys.sort
      if options[:only].any?
        attribute_names &= options[:only]
      elsif options[:except].any?
        attribute_names -= options[:except]
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
