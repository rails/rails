require 'action_view/body_parts/future'

module ActionView
  module BodyParts
    class Queued < Future
      def initialize(job, &block)
        super(&block)
        enqueue(job)
      end

      protected
        def enqueue(job)
          @receipt = submit(job)
        end

        def finish
          @parts << redeem(@receipt)
        end
    end
  end
end
