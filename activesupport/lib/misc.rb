def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, nil
  begin
    yield
  ensure
    $VERBOSE = old_verbose
  end
end

class Hash
  # Return a new hash with all keys converted to symbols.
  def symbolize_keys
    inject({}) do |options, (key, value)|
      options[key.to_sym] = value
      options
    end
  end

  # Destructively convert all keys to symbols.
  def symbolize_keys!
    keys.each do |key|
      unless key.is_a?(Symbol)
        self[key.to_sym] = self[key]
        delete(key)
      end
    end
    self
  end

  alias_method :to_options,  :symbolize_keys
  alias_method :to_options!, :symbolize_keys!
end
