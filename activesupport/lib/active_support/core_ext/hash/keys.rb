# frozen_string_literal: true

class Hash
  DEEP_TRANSFORM_KEYS_DEFAULT = Object.new
  private_constant :DEEP_TRANSFORM_KEYS_DEFAULT
  # Returns a new hash with all keys converted to strings.
  #
  #   hash = { name: 'Rob', age: '28' }
  #
  #   hash.stringify_keys
  #   # => {"name"=>"Rob", "age"=>"28"}
  def stringify_keys
    transform_keys(&:to_s)
  end

  # Destructively converts all keys to strings. Same as
  # +stringify_keys+, but modifies +self+.
  def stringify_keys!
    transform_keys!(&:to_s)
  end

  # Returns a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  #
  #   hash = { 'name' => 'Rob', 'age' => '28' }
  #
  #   hash.symbolize_keys
  #   # => {:name=>"Rob", :age=>"28"}
  def symbolize_keys
    transform_keys { |key| key.to_sym rescue key }
  end
  alias_method :to_options,  :symbolize_keys

  # Destructively converts all keys to symbols, as long as they respond
  # to +to_sym+. Same as +symbolize_keys+, but modifies +self+.
  def symbolize_keys!
    transform_keys! { |key| key.to_sym rescue key }
  end
  alias_method :to_options!, :symbolize_keys!

  # Validates all keys in a hash match <tt>*valid_keys</tt>, raising
  # +ArgumentError+ on a mismatch.
  #
  # Note that keys are treated differently than HashWithIndifferentAccess,
  # meaning that string and symbol keys will not match.
  #
  #   { name: 'Rob', years: '28' }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key: :years. Valid keys are: :name, :age"
  #   { name: 'Rob', age: '28' }.assert_valid_keys('name', 'age') # => raises "ArgumentError: Unknown key: :name. Valid keys are: 'name', 'age'"
  #   { name: 'Rob', age: '28' }.assert_valid_keys(:name, :age)   # => passes, raises nothing
  def assert_valid_keys(*valid_keys)
    valid_keys.flatten!
    each_key do |k|
      unless valid_keys.include?(k)
        raise ArgumentError.new("Unknown key: #{k.inspect}. Valid keys are: #{valid_keys.map(&:inspect).join(', ')}")
      end
    end
  end

  # Returns a new hash with all keys converted by the block operation.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  # An optional hash argument can be provided to map keys to new keys.
  # Any key not given will be mapped using the provided block, or remain the same if no block is given.
  #
  #  hash = { person: { name: 'Rob', age: '28' } }
  #
  #  hash.deep_transform_keys{ |key| key.to_s.upcase }
  #  # => {"PERSON"=>{"NAME"=>"Rob", "AGE"=>"28"}}
  #
  #  hash.deep_transform_keys(person: :user, name: :nickname)
  #  # => {:user=>{:nickname=>"Rob", :age=>"28"}}
  def deep_transform_keys(keys_hash = DEEP_TRANSFORM_KEYS_DEFAULT, &block)
    return to_enum(:deep_transform_keys) if keys_hash == DEEP_TRANSFORM_KEYS_DEFAULT && !block_given?
    keys_hash = _deep_transform_keys_convert_argument(keys_hash)
    _deep_transform_keys_in_object(self, keys_hash, &block)
  end

  # Destructively converts all keys by using the block operation.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  # An optional hash argument can be provided to map keys to new keys.
  def deep_transform_keys!(keys_hash = DEEP_TRANSFORM_KEYS_DEFAULT, &block)
    return to_enum(:deep_transform_keys!) if keys_hash == DEEP_TRANSFORM_KEYS_DEFAULT && !block_given?
    keys_hash = _deep_transform_keys_convert_argument(keys_hash)
    _deep_transform_keys_in_object!(self, keys_hash, &block)
  end

  # Returns a new hash with all keys converted to strings.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  #
  #   hash = { person: { name: 'Rob', age: '28' } }
  #
  #   hash.deep_stringify_keys
  #   # => {"person"=>{"name"=>"Rob", "age"=>"28"}}
  def deep_stringify_keys
    deep_transform_keys(&:to_s)
  end

  # Destructively converts all keys to strings.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  def deep_stringify_keys!
    deep_transform_keys!(&:to_s)
  end

  # Returns a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+. This includes the keys from the root hash
  # and from all nested hashes and arrays.
  #
  #   hash = { 'person' => { 'name' => 'Rob', 'age' => '28' } }
  #
  #   hash.deep_symbolize_keys
  #   # => {:person=>{:name=>"Rob", :age=>"28"}}
  def deep_symbolize_keys
    deep_transform_keys { |key| key.to_sym rescue key }
  end

  # Destructively converts all keys to symbols, as long as they respond
  # to +to_sym+. This includes the keys from the root hash and from all
  # nested hashes and arrays.
  def deep_symbolize_keys!
    deep_transform_keys! { |key| key.to_sym rescue key }
  end

  private
    # Support methods for deep transforming nested hashes and arrays.
    def _deep_transform_keys_in_object(object, keys_hash, &block)
      case object
      when Hash
        object.each_with_object(self.class.new) do |(old_key, value), result|
          new_key =
            if keys_hash&.has_key?(old_key)
              keys_hash[old_key]
            elsif block_given?
              yield(old_key)
            else
              old_key
            end
          result[new_key] = _deep_transform_keys_in_object(value, keys_hash, &block)
        end
      when Array
        object.map { |e| _deep_transform_keys_in_object(e, keys_hash, &block) }
      else
        object
      end
    end

    def _deep_transform_keys_in_object!(object, keys_hash, &block)
      case object
      when Hash
        object.keys.each do |old_key|
          new_key =
            if keys_hash&.has_key?(old_key)
              keys_hash[old_key]
            elsif block_given?
              yield(old_key)
            else
              old_key
            end
          value = object.delete(old_key)
          object[new_key] = _deep_transform_keys_in_object!(value, keys_hash, &block)
        end
        object
      when Array
        object.map! { |e| _deep_transform_keys_in_object!(e, keys_hash, &block) }
      else
        object
      end
    end

    def _deep_transform_keys_convert_argument(keys_hash)
      keys_hash != DEEP_TRANSFORM_KEYS_DEFAULT ? keys_hash.to_hash : nil
    end
end
