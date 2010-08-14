require 'active_support/ordered_hash'

# Usually key value pairs are handled something like this:
#
#   h = ActiveSupport::OrderedOptions.new
#   h[:boy] = 'John'
#   h[:girl] = 'Mary'
#   h[:boy]  # => 'John'
#   h[:girl] # => 'Mary'
#
# Using <tt>OrderedOptions</tt> above code could be reduced to:
#
#   h = ActiveSupport::OrderedOptions.new
#   h.boy = 'John'
#   h.girl = 'Mary'
#   h.boy  # => 'John'
#   h.girl # => 'Mary'
#
module ActiveSupport #:nodoc:
  class OrderedOptions < OrderedHash
    def []=(key, value)
      super(key.to_sym, value)
    end

    def [](key)
      super(key.to_sym)
    end

    def method_missing(name, *args)
      if name.to_s =~ /(.*)=$/
        self[$1.to_sym] = args.first
      else
        self[name]
      end
    end
  end

  class InheritableOptions < OrderedOptions
    def initialize(parent)
      super() { |h,k| parent[k] }
    end
  end
end
