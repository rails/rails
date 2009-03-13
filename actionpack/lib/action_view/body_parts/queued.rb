require 'action_view/body_parts/future'

module ActionView
  module BodyParts
    class Queued < Future
      attr_reader :body

      def initialize(job)
        @receipt = enqueue(job)
      end

      protected
        def finish
          @body = redeem(@receipt)
        end
    end
  end
end
