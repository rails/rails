module ActionDispatch
  module Session
    class JsonSerializer
      def self.load(value)
        JSON.parse(value, quirks_mode: true)
      end

      def self.dump(value)
        JSON.generate(value, quirks_mode: true)
      end
    end
  end
end
