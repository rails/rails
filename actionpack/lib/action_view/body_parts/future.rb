module ActionView
  module BodyParts
    class Future
      def initialize(&block)
        @block = block
        @parts = []
      end

      def to_s
        finish
        body
      end

      protected
        def work
          @block.call(@parts)
        end

        def body
          str = ''
          @parts.each { |part| str << part.to_s }
          str
        end
    end
  end
end
