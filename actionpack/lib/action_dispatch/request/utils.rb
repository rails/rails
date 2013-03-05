module ActionDispatch
  class Request < Rack::Request
    class Utils # :nodoc:
      class << self
        # Remove nils from the params hash
        def deep_munge(hash)
          hash.each do |k, v|
            case v
            when Array
              v.grep(Hash) { |x| deep_munge(x) }
              v.compact!
            when Hash
              deep_munge(v)
            end
          end

          hash
        end
      end
    end
  end
end

