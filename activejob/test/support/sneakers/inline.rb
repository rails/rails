require "sneakers"

module Sneakers
  module Worker
    module ClassMethods
      def enqueue(msg)
        worker = new(nil, nil, {})
        worker.work(*msg)
      end
    end
  end
end
