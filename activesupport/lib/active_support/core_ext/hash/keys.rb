class Hash
  # Return a new hash with all keys converted to strings.
  def stringify_keys
    dup.stringify_keys!
  end

  # Destructively convert all keys to strings.
  def stringify_keys!
    keys.each do |key|
      self[stringified_key = key.to_s] = delete(key)
      if self[stringified_key].instance_of? Array
        self[stringified_key].each  do |i| 
          i.stringify_keys! if i.respond_to? :stringify_keys!
        end
      elsif self[stringified_key].respond_to? :stringify_keys!
        self[stringified_key].stringify_keys!
      end
    end
    self
  end

  # Return a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  def symbolize_keys
    dup.symbolize_keys!
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+.
  def symbolize_keys!
    keys.each do |key|
      self[symbolized_key = (key.to_sym rescue key) || key] = delete(key)
      if self[symbolized_key].instance_of? Array
        self[symbolized_key].map! { |i| i.symbolize_keys }
      elsif self[symbolized_key].respond_to? :symbolize_keys
        self[symbolized_key] = self[symbolized_key].symbolize_keys
        # self[symbolized_key].symbolize_keys!
      end
    end
    self
  end

  alias_method :to_options,  :symbolize_keys
  alias_method :to_options!, :symbolize_keys!

  # Validate all keys in a hash match *valid keys, raising ArgumentError on a mismatch.
  # Note that keys are NOT treated indifferently, meaning if you use strings for keys but assert symbols
  # as keys, this will fail.
  #
  # ==== Examples
  #   { :name => "Rob", :years => "28" }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key: years"
  #   { :name => "Rob", :age => "28" }.assert_valid_keys("name", "age") # => raises "ArgumentError: Unknown key: name"
  #   { :name => "Rob", :age => "28" }.assert_valid_keys(:name, :age) # => passes, raises nothing
  def assert_valid_keys(*valid_keys)
    valid_keys.flatten!
    each_key do |k|
      raise(ArgumentError, "Unknown key: #{k}") unless valid_keys.include?(k)
    end
  end
end
