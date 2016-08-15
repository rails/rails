require_relative "../support/job_buffer"

class HelloJob < ActiveJob::Base
  def perform(greeter = "David")
    JobBuffer.add("#{greeter} says hello")
  end
end
