module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      # Allows for reverse merging where its the keys in the calling hash that wins over those in the <tt>other_hash</tt>.
      # This is particularly useful for initializing an incoming option hash with default values:
      #
      #   def setup(options = {})
      #     options.reverse_merge! :size => 25, :velocity => 10
      #   end
      #
      # The default :size and :velocity is only set if the +options+ passed in doesn't already have those keys set.
      module ReverseMerge
        def reverse_merge(other_hash)
          other_hash.merge(self)
        end

        def reverse_merge!(other_hash)
          replace(reverse_merge(other_hash))
        end

        alias_method :reverse_update, :reverse_merge
      end
    end
  end
end