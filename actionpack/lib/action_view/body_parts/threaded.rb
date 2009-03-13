require 'action_view/body_parts/future'

module ActionView
  module BodyParts
    class Threaded < Future
      def initialize(concurrent = false, &block)
        super(&block)
        concurrent ? start : work
      end

      protected
        def start
          @worker = Thread.new { work }
        end

        def finish
          @worker.join if @worker && @worker.alive?
        end
    end
  end
end
