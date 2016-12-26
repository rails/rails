class Hash
  unless Hash.instance_methods(false).include?(:compact)
    # Returns a hash with non +nil+ values.
    #
    #   hash = { a: true, b: false, c: nil}
    #   hash.compact # => { a: true, b: false}
    #   hash # => { a: true, b: false, c: nil}
    #   { c: nil }.compact # => {}
    def compact
      self.select { |_, value| !value.nil? }
    end
  end

  unless Hash.instance_methods(false).include?(:compact!)
    # Replaces current hash with non +nil+ values.
    #
    #   hash = { a: true, b: false, c: nil}
    #   hash.compact! # => { a: true, b: false}
    #   hash # => { a: true, b: false}
    def compact!
      self.reject! { |_, value| value.nil? }
    end
  end
end
