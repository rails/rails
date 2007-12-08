module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Keys
        # Return a new hash with all keys converted to strings.
        def stringify_keys
          inject({}) do |options, (key, value)|
            options[key.to_s] = value
            options
          end
        end

        # Destructively convert all keys to strings.
        def stringify_keys!
          keys.each do |key|
            unless key.class.to_s == "String" # weird hack to make the tests run when string_ext_test.rb is also running
              self[key.to_s] = self[key]
              delete(key)
            end
          end
          self
        end

        # Return a new hash with all keys converted to symbols.
        def symbolize_keys
          inject({}) do |options, (key, value)|
            options[key.to_sym || key] = value
            options
          end
        end

        # Destructively convert all keys to symbols.
        def symbolize_keys!
          self.replace(self.symbolize_keys)
        end

        alias_method :to_options,  :symbolize_keys
        alias_method :to_options!, :symbolize_keys!

        # Validate all keys in a hash match *valid keys, raising ArgumentError on a mismatch.
        # Note that keys are NOT treated indifferently, meaning if you use strings for keys but assert symbol
        # as keys, this will fail.
        # examples:
        #   { :name => "Rob", :years => "28" }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key(s): years"
        #   { :name => "Rob", :age => "28" }.assert_valid_keys("name", "age") # => raises "ArgumentError: Unknown key(s): years, name"
        #   { :name => "Rob", :age => "28" }.assert_valid_keys(:name, :age) # => passes, raises nothing
        def assert_valid_keys(*valid_keys)
          unknown_keys = keys - [valid_keys].flatten
          raise(ArgumentError, "Unknown key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
        end
      end
    end
  end
end
