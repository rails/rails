class Hash
  # Traverses a hash and returns the value associated with the last key provided.  For example,
  #
  #  options = { level1: { level2: { level3: 3 } } }
  #  options.traverse :level1, :level2, :level3 #=> 3
  #
  # If a block is provided its value will be returned if the key does not exist or its value is nil.
  #
  #  value = options.traverse(:level1, :non_existent_key) { 5 }
  #  puts value #=> 5
  #
  # This is particularly useful for fetching values from deeply nested api responses or params hashes.
  #
  def traverse(*args, &block)
    val = args.inject(self) { |hash, arg| hash[arg] || break }
    val ||= (block.call if block)
  end
end
