class Hash
  unless Hash.instance_methods(false).include?(:compact)
    # Returns a hash with non +nil+ values.
    #
    #   hash = { a: true, b: false, c: nil }
    #   hash.compact        # => { a: true, b: false }
    #   hash                # => { a: true, b: false, c: nil }
    #   { c: nil }.compact  # => {}
    #   { c: true }.compact # => { c: true }
    def compact
      select { |_, value| !value.nil? }
    end
  end

  unless Hash.instance_methods(false).include?(:compact!)
    # Replaces current hash with non +nil+ values.
    # Returns nil if no changes were made, otherwise returns the hash.
    #
    #   hash = { a: true, b: false, c: nil }
    #   hash.compact!        # => { a: true, b: false }
    #   hash                 # => { a: true, b: false }
    #   { c: true }.compact! # => nil
    def compact!
      reject! { |_, value| value.nil? }
    end
  end
end
