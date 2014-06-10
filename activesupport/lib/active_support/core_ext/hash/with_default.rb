class Hash
  # Set the default value or proc for a hash and return the given hash. This is useful for
  # using code that generates hashes in a functional style:
  #
  #   people.group_by(:first_name).with_default{[]}
  #
  def with_default(*args, &block)
    if block_given?
      raise ArgumentError, "cannot accept both a block and an argument" if args.length > 0
      self.default_proc = block
    elsif args.length > 0
      raise ArgumentError, "accepts only a single argument" if args.length > 1
      default_value = args[0]
      self.default = default_value
    else
      raise ArgumentError, "must be passed a block or an argument"
    end
    self
  end
end
