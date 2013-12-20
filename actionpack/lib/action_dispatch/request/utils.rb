module ActionDispatch
  class Request < Rack::Request
    class Utils # :nodoc:

      mattr_accessor :perform_deep_munge
      self.perform_deep_munge = true

      class << self
        # Remove nils from the params hash
        def deep_munge(hash)
          return hash unless perform_deep_munge

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

