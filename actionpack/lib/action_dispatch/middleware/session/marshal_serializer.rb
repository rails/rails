module ActionDispatch
  module Session
    class MarshalSerializer
      def self.load(value)
        Marshal.load(value)
      end

      def self.dump(value)
        Marshal.dump(value)
      end
    end
  end
end

