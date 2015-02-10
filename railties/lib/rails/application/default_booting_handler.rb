module Rails
  class Application
    class DefaultBootingHandler
      def self.call!(&block)
        new.call!(&block)
      end

      def call!(&block)
        block.call
      end
    end
  end
end
