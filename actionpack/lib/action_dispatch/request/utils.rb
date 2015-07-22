module ActionDispatch
  class Request < Rack::Request
    class Utils # :nodoc:

      mattr_accessor :perform_deep_munge
      self.perform_deep_munge = true

      def self.normalize_encode_params(params)
        ParamEncoder.normalize_encode_params params
      end

      class ParamEncoder
        # Convert nested Hash to HashWithIndifferentAccess.
        #
        def self.normalize_encode_params(params)
          case params
          when Array
            handle_array params
          when Hash
            if params.has_key?(:tempfile)
              ActionDispatch::Http::UploadedFile.new(params)
            else
              params.each_with_object({}) do |(key, val), new_hash|
                new_hash[key] = normalize_encode_params(val)
              end.with_indifferent_access
            end
          else
            params
          end
        end

        def self.handle_array(params)
          params.map! { |el| normalize_encode_params(el) }
        end
      end

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

