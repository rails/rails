# frozen_string_literal: true

require "queue_classic"
require "active_support/core_ext/module/redefine_method"

module QC
  class Queue
    redefine_method(:enqueue) do |method, *args|
      receiver_str, _, message = method.rpartition(".")
      receiver = eval(receiver_str)
      receiver.send(message, *args)
    end

    redefine_method(:enqueue_in) do |seconds, method, *args|
      receiver_str, _, message = method.rpartition(".")
      receiver = eval(receiver_str)
      receiver.send(message, *args)
    end

    redefine_method(:enqueue_at) do |not_before, method, *args|
      receiver_str, _, message = method.rpartition(".")
      receiver = eval(receiver_str)
      receiver.send(message, *args)
    end
  end
end
