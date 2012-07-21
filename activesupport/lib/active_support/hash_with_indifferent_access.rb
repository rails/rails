require 'active_support/core_ext/hash/keys'

# This class has dubious semantics and we only have it so that
# people can write <tt>params[:key]</tt> instead of <tt>params['key']</tt>
# and they get the same value for both keys.

module ActiveSupport
  class HashWithIndifferentAccess < Hash
    
    # Always returns true, so that <tt>Array#extract_options!</tt> finds members of this class.
    def extractable_options?
      true
    end

    def with_indifferent_access
      dup
    end

    def nested_under_indifferent_access
      self
    end

    def initialize(constructor = {})
      if constructor.is_a?(Hash)
        super()
        update(constructor)
      else
        super(constructor)
      end
    end

    def default(key = nil)
      if key.is_a?(Symbol) && include?(key = key.to_s)
        self[key]
      else
        super
      end
    end

    def self.new_from_hash_copying_default(hash)
      new(hash).tap do |new_hash|
        new_hash.default = hash.default
      end
    end

    alias_method :regular_writer, :[]= unless method_defined?(:regular_writer)
    alias_method :regular_update, :update unless method_defined?(:regular_update)

    # Assigns a new value to the hash:
    #
    #   hash = HashWithIndifferentAccess.new
    #   hash[:key] = "value"
    #
    def []=(key, value)
      regular_writer(convert_key(key), convert_value(value))
    end

    alias_method :store, :[]=

    # Updates the instantized hash with values from the second:
    #
    #   hash_1 = HashWithIndifferentAccess.new
    #   hash_1[:key] = "value"
    #
    #   hash_2 = HashWithIndifferentAccess.new
    #   hash_2[:key] = "New Value!"
    #
    #   hash_1.update(hash_2) # => {"key"=>"New Value!"}
    #
    def update(other_hash)
      if other_hash.is_a? HashWithIndifferentAccess
        super(other_hash)
      else
        other_hash.each_pair { |key, value| regular_writer(convert_key(key), convert_value(value)) }
        self
      end
    end

    alias_method :merge!, :update

    # Checks the hash for a key matching the argument passed in:
    #
    #   hash = HashWithIndifferentAccess.new
    #   hash["key"] = "value"
    #   hash.key? :key  # => true
    #   hash.key? "key" # => true
    #
    def key?(key)
      super(convert_key(key))
    end

    alias_method :include?, :key?
    alias_method :has_key?, :key?
    alias_method :member?, :key?

    # Same as <tt>Hash#fetch</tt> where the key passed as argument can be
    # either a string or a symbol:
    #
    #   counters = HashWithIndifferentAccess.new
    #   counters[:foo] = 1
    #
    #   counters.fetch("foo")          # => 1
    #   counters.fetch(:bar, 0)        # => 0
    #   counters.fetch(:bar) {|key| 0} # => 0
    #   counters.fetch(:zoo)           # => KeyError: key not found: "zoo"
    #
    def fetch(key, *extras)
      super(convert_key(key), *extras)
    end

    # Returns an array of the values at the specified indices:
    #
    #   hash = HashWithIndifferentAccess.new
    #   hash[:a] = "x"
    #   hash[:b] = "y"
    #   hash.values_at("a", "b") # => ["x", "y"]
    #
    def values_at(*indices)
      indices.collect {|key| self[convert_key(key)]}
    end

    # Returns an exact copy of the hash.
    def dup
      self.class.new(self).tap do |new_hash|
        new_hash.default = default
      end
    end

    # Merges the instantized and the specified hashes together, giving precedence to the values from the second hash.
    # Does not overwrite the existing hash.
    def merge(hash)
      self.dup.update(hash)
    end

    # Performs the opposite of merge, with the keys and values from the first hash taking precedence over the second.
    # This overloaded definition prevents returning a regular hash, if reverse_merge is called on a <tt>HashWithDifferentAccess</tt>.
    def reverse_merge(other_hash)
      super self.class.new_from_hash_copying_default(other_hash)
    end

    def reverse_merge!(other_hash)
      replace(reverse_merge( other_hash ))
    end

    # Removes a specified key from the hash.
    def delete(key)
      super(convert_key(key))
    end

    def stringify_keys!; self end
    def stringify_keys; dup end
    undef :symbolize_keys!
    def symbolize_keys; to_hash.symbolize_keys end
    def to_options!; self end

    # Convert to a Hash with String keys.
    def to_hash
      Hash.new(default).merge!(self)
    end

    protected
      def convert_key(key)
        key.kind_of?(Symbol) ? key.to_s : key
      end

      def convert_value(value)
        if value.is_a? Hash
          value.nested_under_indifferent_access
        elsif value.is_a?(Array)
          value.dup.replace(value.map { |e| convert_value(e) })
        else
          value
        end
      end
  end
end

HashWithIndifferentAccess = ActiveSupport::HashWithIndifferentAccess
