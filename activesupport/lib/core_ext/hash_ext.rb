class Hash
  def assert_valid_keys(valid_keys)
    unknown_keys = keys - valid_keys
    raise(ArgumentError, "Unknown key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
  end
end