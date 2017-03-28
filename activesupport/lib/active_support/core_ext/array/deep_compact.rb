class Array
  unless Array.instance_methods(false).include?(:deep_compact)
    # Returns a array with non +nil+ values. Deep evaluated.
    #
    #   array = [ true, false, nil, [ nil, 1] ]
    #   array.deep_compact        # => [ true, false, [ 1] ]
    #   array                # => [ true, false, nil, [ nil, 1] ]
    #   [ nil ].deep_compact  # => []
    #   [ true ].deep_compact # => [ true ]
    def deep_compact
      dup.deep_compact!
    end
  end

  unless Array.instance_methods(false).include?(:deep_compact!)
    # Replaces current array with non +nil+ values. Deep evaluated.
    # Returns +nil+ if no changes were made, otherwise returns the array.
    #
    #   array = [ true, false, nil ]
    #   array.deep_compact!        # => [ true, false ]
    #   array                      # => [ true, false ]
    #   [ true ].deep_compact! # => nil
    def deep_compact!
      compact!
      each do |e|
        if e.respond_to? :deep_compact!
          e.deep_compact
        end
        self.delete(e) if e.nil?
      end
    end
  end
end
