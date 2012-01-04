require 'yaml'

YAML.add_builtin_type("omap") do |type, val|
  ActiveSupport::OrderedHash[val.map{ |v| v.to_a.first }]
end

module ActiveSupport
  # The order of iteration over hashes in Ruby 1.8 is undefined. For example, you do not know the
  # order in which +keys+ will return keys, or +each+ yield pairs. <tt>ActiveSupport::OrderedHash</tt>
  # implements a hash that preserves insertion order, as in Ruby 1.9:
  #
  #   oh = ActiveSupport::OrderedHash.new
  #   oh[:a] = 1
  #   oh[:b] = 2
  #   oh.keys # => [:a, :b], this order is guaranteed
  #
  # <tt>ActiveSupport::OrderedHash</tt> is namespaced to prevent conflicts with other implementations.
  class OrderedHash < ::Hash
    def to_yaml_type
      "!tag:yaml.org,2002:omap"
    end

    def encode_with(coder)
      coder.represent_seq '!omap', map { |k,v| { k => v } }
    end

    def nested_under_indifferent_access
      self
    end

    # Returns true to make sure that this hash is extractable via <tt>Array#extract_options!</tt>
    def extractable_options?
      true
    end
  end
end
