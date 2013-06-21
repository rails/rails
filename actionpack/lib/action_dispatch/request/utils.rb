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
              if v.empty?
                hash[k] = []
              else
                v.compact!
                hash[k] = nil if v.empty?
               end
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

