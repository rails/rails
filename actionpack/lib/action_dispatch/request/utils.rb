module ActionDispatch
  class Request < Rack::Request
    class Utils # :nodoc:

      mattr_accessor :perform_deep_munge
      self.perform_deep_munge = true

      class << self
        # Remove nils from the params hash
        def deep_munge(hash, keys = [])
          return hash unless perform_deep_munge

          hash.each do |k, v|
            keys << k
            case v
            when Array
              v.grep(Hash) { |x| deep_munge(x, keys) }
              v.compact!
              if v.empty?
                hash[k] = nil
                ActiveSupport::Notifications.instrument("deep_munge.action_controller", keys: keys)
              end
            when Hash
              deep_munge(v, keys)
            end
            keys.pop
          end

          hash
        end
      end
    end
  end
end

