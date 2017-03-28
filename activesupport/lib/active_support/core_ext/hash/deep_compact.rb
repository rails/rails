class Hash
  unless Hash.instance_methods(false).include?(:deep_compact)
    # Returns a hash with non +nil+ values. Deep evaluated.
    #
    #   hash = { a: true, b: false, c: nil, d: { e: nil, f: 1} }
    #   hash.deep_compact        # => { a: true, b: false, d: { f: 1} }
    #   hash                # => { a: true, b: false, c: nil, d: { e: nil, f: 1} }
    #   { c: nil }.deep_compact  # => {}
    #   { c: true }.deep_compact # => { c: true }
    def deep_compact
      dup.deep_compact!
    end
  end

  unless Hash.instance_methods(false).include?(:deep_compact!)
    # Replaces current hash with non +nil+ values. Deep evaluated.
    # Returns +nil+ if no changes were made, otherwise returns the hash.
    #
    #   hash = { a: true, b: false, c: nil }
    #   hash.deep_compact!        # => { a: true, b: false }
    #   hash                      # => { a: true, b: false }
    #   { c: true }.deep_compact! # => nil
    def deep_compact!
      compact!
      self.each_pair do |k, v|
        if self[k].respond_to? :deep_compact
          self[k].deep_compact
        end
        self.delete(k) if self[k].nil?
      end
    end
  end
end
