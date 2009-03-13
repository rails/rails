require 'action_view/body_parts/future'

module ActionView
  module BodyParts
    class Threaded < Future
      def initialize(concurrent = false, &block)
        @block = block
        @parts = []
        concurrent ? start : work
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

        def start
          @worker = Thread.new { work }
        end

        def finish
          @worker.join if @worker && @worker.alive?
        end
    end
  end
end
