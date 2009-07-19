# This class has dubious semantics and we only have it so that
# people can write params[:key] instead of params['key']
# and they get the same value for both keys.

module ActiveSupport
  class HashWithIndifferentAccess < Hash
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
      other_hash.each_pair { |key, value| regular_writer(convert_key(key), convert_value(value)) }
      self
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

    # Fetches the value for the specified key, same as doing hash[key]
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
      HashWithIndifferentAccess.new(self)
    end

    # Merges the instantized and the specified hashes together, giving precedence to the values from the second hash
    # Does not overwrite the existing hash.
    def merge(hash)
      self.dup.update(hash)
    end

    # Performs the opposite of merge, with the keys and values from the first hash taking precedence over the second.
    # This overloaded definition prevents returning a regular hash, if reverse_merge is called on a HashWithDifferentAccess.
    def reverse_merge(other_hash)
      super other_hash.with_indifferent_access
    end

    def reverse_merge!(other_hash)
      replace(reverse_merge( other_hash ))
    end

    # Removes a specified key from the hash.
    def delete(key)
      super(convert_key(key))
    end

    def stringify_keys!; self end
    def symbolize_keys!; self end
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
        case value
        when Hash
          value.with_indifferent_access
        when Array
          value.collect { |e| e.is_a?(Hash) ? e.with_indifferent_access : e }
        else
          value
        end
      end
  end
end

HashWithIndifferentAccess = ActiveSupport::HashWithIndifferentAccess
