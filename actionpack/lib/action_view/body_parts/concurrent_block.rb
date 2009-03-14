module ActionView
  module BodyParts
    class ConcurrentBlock
      def initialize(&block)
        @block = block
        @body = []
        start
      end

      def to_s
        finish
        @body.join
      end

      protected
        def start
          @worker = Thread.new { @block.call(@body) }
        end

        def finish
          @worker.join if @worker && @worker.alive?
        end
    end
  end
end
