def assert_filtered_out(params, key)
  assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
end
