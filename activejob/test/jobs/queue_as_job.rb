require_relative "../support/job_buffer"

class QueueAsJob < ActiveJob::Base
  MY_QUEUE = :low_priority
  queue_as MY_QUEUE

  def perform(greeter = "David")
    JobBuffer.add("#{greeter} says hello")
  end
end
