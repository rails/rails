module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Keys

        # Return a new hash with all keys converted to symbols.
        def symbolize_keys
          inject({}) do |options, (key, value)|
            options[key.to_sym] = value
            options
          end
        end

        # Destructively convert all keys to symbols.
        def symbolize_keys!
          keys.each do |key|
            unless key.is_a?(Symbol)
              self[key.to_sym] = self[key]
              delete(key)
            end
          end
          self
        end

        alias_method :to_options,  :symbolize_keys
        alias_method :to_options!, :symbolize_keys!

        def assert_valid_keys(valid_keys)
          unknown_keys = keys - valid_keys
          raise(ArgumentError, "Unknown key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
        end
      end
    end
  end
end
