module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      # Allows for deep merging
      module DeepMerge
        # Returns a new hash with +self+ and +other_hash+ merged recursively.
        def deep_merge(other_hash)
          self.merge(other_hash) do |key, oldval, newval|
            oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
            newval = newval.to_hash if newval.respond_to?(:to_hash)
            oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
          end
        end

        # Returns a new hash with +self+ and +other_hash+ merged recursively.
        # Modifies the receiver in place.
        def deep_merge!(other_hash)
          replace(deep_merge(other_hash))
        end
      end
    end
  end
end
