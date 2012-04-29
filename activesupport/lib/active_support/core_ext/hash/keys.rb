class Hash
  # Return a new hash with all keys converted using the block operation.
  #
  #  { :name => 'Rob', :years => '28' }.transform_keys{ |key| key.to_s.upcase }
  #  # => { "NAME" => "Rob", "YEARS" => "28" }
  def transform_keys
    result = {}
    keys.each do |key|
      result[yield(key)] = self[key]
    end
    result
  end

  # Destructively convert all keys using the block operations.
  # Same as transform_keys but modifies +self+
  def transform_keys!
    keys.each do |key|
      self[yield(key)] = delete(key)
    end
    self
  end

  # Return a new hash with all keys converted to strings.
  #
  #   { :name => 'Rob', :years => '28' }.stringify_keys
  #   #=> { "name" => "Rob", "years" => "28" }
  def stringify_keys
    transform_keys{ |key| key.to_s }
  end

  # Destructively convert all keys to strings. Same as
  # +stringify_keys+, but modifies +self+.
  def stringify_keys!
    transform_keys!{ |key| key.to_s }
  end

  # Return a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  #
  #   { 'name' => 'Rob', 'years' => '28' }.symbolize_keys
  #   #=> { :name => "Rob", :years => "28" }
  def symbolize_keys
    transform_keys{ |key| key.to_sym rescue key }
  end
  alias_method :to_options,  :symbolize_keys

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+. Same as +symbolize_keys+, but modifies +self+.
  def symbolize_keys!
    transform_keys!{ |key| key.to_sym rescue key }
  end
  alias_method :to_options!, :symbolize_keys!

  # Validate all keys in a hash match *valid keys, raising ArgumentError on a mismatch.
  # Note that keys are NOT treated indifferently, meaning if you use strings for keys but assert symbols
  # as keys, this will fail.
  #
  #   { :name => 'Rob', :years => '28' }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key: years"
  #   { :name => 'Rob', :age => '28' }.assert_valid_keys('name', 'age') # => raises "ArgumentError: Unknown key: name"
  #   { :name => 'Rob', :age => '28' }.assert_valid_keys(:name, :age) # => passes, raises nothing
  def assert_valid_keys(*valid_keys)
    valid_keys.flatten!
    each_key do |k|
      raise ArgumentError.new("Unknown key: #{k}") unless valid_keys.include?(k)
    end
  end

  # Return a new hash with all keys converted to strings.
  # This includes the keys from the root hash and from all
  # nested hashes.
  def deep_stringify_keys
    result = {}
    each do |key, value|
      result[key.to_s] = value.is_a?(Hash) ? value.deep_stringify_keys : value
    end
    result
  end

  # Destructively convert all keys to strings.
  # This includes the keys from the root hash and from all
  # nested hashes.
  def deep_stringify_keys!
    keys.each do |key|
      val = delete(key)
      self[key.to_s] = val.is_a?(Hash) ? val.deep_stringify_keys! : val
    end
    self
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+. This includes the keys from the root hash and from all
  # nested hashes.
  def deep_symbolize_keys!
    keys.each do |key|
      val = delete(key)
      self[(key.to_sym rescue key)] = val.is_a?(Hash) ? val.deep_stringify_keys! : val
    end
    self
  end

  # Return a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+. This includes the keys from the root hash
  # and from all nested hashes.
  def deep_symbolize_keys
    result = {}
    each do |key, value|
      result[(key.to_sym rescue key)] = value.is_a?(Hash) ? value.deep_symbolize_keys : value
    end
    result
  end
end
