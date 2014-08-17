require 'queue_classic'

module QC
  class Queue
    def enqueue(method, *args)
      receiver_str, _, message = method.rpartition('.')
      receiver = eval(receiver_str)
      receiver.send(message, *args)
    end
  end
end
