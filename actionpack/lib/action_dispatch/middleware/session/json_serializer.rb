module ActionDispatch
  module Session
    class JsonSerializer
      def self.load(value)
        case result = JSON.parse(value, quirks_mode: true)
        when Hash
          result.with_indifferent_access
        else
          result
        end
      end

      def self.dump(value)
        JSON.generate(value, quirks_mode: true)
      end
    end
  end
end
